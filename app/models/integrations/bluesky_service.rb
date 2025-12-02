module Integrations
  # COPY from: https://t27duck.com/posts/17-a-bluesky-at-proto-api-example-in-ruby
  class BlueskyService
    include ContentBuilder

    TOKEN_CACHE_KEY = :bluesky_token_data

    def initialize
      @settings = Crosspost.bluesky
      return unless @settings.present?

      @username = @settings.username
      @password = @settings.app_password
      @server_url = @settings.server_url.presence || "https://bsky.social/xrpc"

      if (token_data = Rails.cache.read(TOKEN_CACHE_KEY))
        process_tokens(token_data)
      end
    end

    def verify(settings)
      if settings[:username].blank? || settings[:app_password].blank?
        return { success: false, error: "App Password and username are required" }
      end

      # Temporarily store the current credentials
      original_username = @username
      original_password = @password
      original_server_url = @server_url

      begin
        @username = settings[:username]
        @password = settings[:app_password]
        @server_url = settings[:server_url]

        # Clear any existing token data
        @token = nil
        @token_expires_at = nil
        Rails.cache.delete(TOKEN_CACHE_KEY)

        # Attempt to generate new tokens with the provided credentials
        verify_tokens
        { success: true }
      rescue => e
        { success: false, error: "Bluesky verification failed: #{e.message}" }
      ensure
        # Restore the original credentials
        @username = original_username
        @password = original_password
        @server_url = original_server_url
      end
    end

    def post(article)
      return unless @settings&.enabled?

      content = build_content(article.slug, article.title, article.content.body.to_plain_text, article.description)

      # 获取文章第一张图片
      first_image = article.first_image_attachment
      Rails.logger.info "Bluesky: first_image_attachment = #{first_image.class}"

      embed = nil

      if first_image
        Rails.logger.info "Bluesky: Attempting to upload image of type: #{first_image.class}"
        embed = upload_image_embed(first_image)
        Rails.logger.info "Bluesky: upload_image_embed result = #{embed.present? ? 'success' : 'failed'}"
      else
        Rails.logger.info "Bluesky: No image found in article"
      end

      begin
        posted_url = skeet(content, embed)
        ActivityLog.create!(
          action: "initiated",
          target: "crosspost",
          level: :info,
          description: "Successfully posted article #{article.title} to Bluesky"
        )

        posted_url
      rescue => e
        ActivityLog.create!(
          action: "failed",
          target: "crosspost",
          level: :error,
          description: "Failed to post article #{article.title} to Bluesky: #{e.message}"
        )
        nil
      end
    end

    # Posts a new message (skeet) to the account and return the direct URL.
    def skeet(message, embed = nil)
      # Generate, refresh, or use an active token.
      verify_tokens

      # URLs and tags are not automatically parsed. Instead we have to manually
      # parse and set facets for each.
      # See: https://docs.bsky.app/docs/advanced-guides/post-richtext
      facets = link_facets(message)
      # facets += tag_facets(message)

      # Build the record - only include embed if it's present
      record = {
        text: message,
        createdAt: Time.now.iso8601,
        langs: [ "en" ],
        facets: facets
      }

      # Only add embed if it's not nil (Bluesky requires $type if embed is present)
      record[:embed] = embed if embed.present?

      body = {
        repo: @user_did,
        collection: "app.bsky.feed.post",
        record: record
      }
      response_body = post_request("#{@server_url}/com.atproto.repo.createRecord", body: body)

      # This is the full atproto URI
      # Ex: "at://did:plc:axbcdefg12345/app.bsky.feed.post/abcdefg12345"
      if response_body["uri"].present?
        "https://bsky.app/profile/#{@settings.username}/post/#{response_body["uri"].split('/').last}"
      end
    end

    def unskeet(skeet_uri)
      # Generate, refresh, or use an active token.
      verify_tokens

      did, nsid, record_key = skeet_uri.delete_prefix("at://").split("/")
      body = { repo: did, collection: nsid, rkey: record_key }
      post_request("#{@server_url}/com.atproto.repo.deleteRecord", body: body)
    end

    # Fetch comments (replies) for a Bluesky post
    # Returns a hash with :comments array and :rate_limit info
    def fetch_comments(post_url)
      default_response = { comments: [], rate_limit: nil }
      return default_response unless @settings&.enabled?
      return default_response if post_url.blank?

      begin
        # Extract AT-URI from Bluesky URL
        at_uri = extract_post_uri_from_url(post_url)
        return default_response unless at_uri

        # Ensure we have a valid token
        verify_tokens

        # Call Bluesky API to get thread with replies
        # Using public API for better rate limits
        api_url = "https://public.api.bsky.app/xrpc/app.bsky.feed.getPostThread"
        uri = URI(api_url)
        uri.query = URI.encode_www_form(uri: at_uri, depth: 10)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5

        request = Net::HTTP::Get.new(uri)
        # Optional: Add auth for better limits, but public API works
        # request["Authorization"] = "Bearer #{@token}" if @token

        response = http.request(request)

        # Parse rate limit headers
        rate_limit_info = parse_rate_limit_headers(response)
        log_rate_limit_status(rate_limit_info)

        # Handle rate limit exceeded
        if response.code == "429"
          handle_rate_limit_exceeded(rate_limit_info)
          return { comments: [], rate_limit: rate_limit_info }
        end

        if response.is_a?(Net::HTTPSuccess)
          thread_data = JSON.parse(response.body)

          # Get the original post URI to identify top-level replies
          original_post_uri = thread_data.dig("thread", "post", "uri")
          original_post_rkey = original_post_uri&.split("/")&.last

          # Get replies from thread (nested structure)
          replies = thread_data.dig("thread", "replies") || []

          # Flatten nested replies into comment list, preserving parent relationships
          # Top-level replies should have parent_external_id = nil, not the original post ID
          comments = flatten_thread_replies(replies, nil)

          { comments: comments, rate_limit: rate_limit_info }
        else
          Rails.logger.error "Failed to fetch Bluesky comments: #{response.code} - #{response.body}"
          { comments: [], rate_limit: rate_limit_info }
        end
      rescue => e
        Rails.logger.error "Error fetching Bluesky comments: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        default_response
      end
    end

    private



    def retrieve_server_token
      token_data = Rails.cache.read(TOKEN_CACHE_KEY)
      if token_data.present?
        process_tokens(token_data)
        @token
      else
        verify_tokens
        @token
      end
    end

    def link_facets(message)
      [].tap do |facets|
        matches = []
        message.scan(URI::RFC2396_PARSER.make_regexp([ "http", "https" ])) { matches << Regexp.last_match }
        matches.each do |match|
          url = match[0]

          # 验证 URL 格式是否正确
          begin
            uri = URI.parse(url)
            # 确保 URL 有 scheme 和 host
            next unless uri.scheme && uri.host
          rescue URI::InvalidURIError
            Rails.logger.warn "Bluesky: Skipping invalid URL in facets: #{url}"
            next
          end

          start, stop = match.byteoffset(0)
          facets << {
            "index" => { "byteStart" => start, "byteEnd" => stop },
            "features" => [ { "uri" => url, "$type" => "app.bsky.richtext.facet#link" } ]
          }
        end
      end
    end

    def tag_facets(message)
      [].tap do |facets|
        matches = []
        message.scan(/(^|[^\w])(#[\w\-]+)/) { matches << Regexp.last_match }
        matches.each do |match|
          start, stop = match.byteoffset(2)
          facets << {
            "index" => { "byteStart" => start, "byteEnd" => stop },
            "features" => [ { "tag" => match[2].delete_prefix("#"), "$type" => "app.bsky.richtext.facet#tag" } ]
          }
        end
      end
    end

    # Makes a POST request to the API.
    def post_request(url, body: {}, auth_token: true, content_type: "application/json")
      uri = URI.parse(url)
      Rails.logger.info "POST request to URL:#{url} and URI:#{uri}"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 4
      http.read_timeout = 4
      http.write_timeout = 4
      request = Net::HTTP::Post.new(uri.path)
      request["content-type"] = content_type

      # This allows the authorization token to:
      #   - Be sent using the currently stored token (true).
      #   - Not send when providing the username/password to generate the token (false).
      #   - Use a different token - like the refresh token (string).
      if auth_token
        token = auth_token.is_a?(String) ? auth_token : @token
        request["Authorization"] = "Bearer #{token}"
      end
      request.body = body.is_a?(Hash) ? body.to_json : body if body.present?
      response = http.request(request)
    raise "#{response.code} response - #{response.body}" unless response.code.to_s.start_with?("2")

      response.content_type == "application/json" ? JSON.parse(response.body) : response.body
    end

    # Generate tokens given an account identifier and app password.
    def generate_tokens
      body = { identifier: @username, password: @password }
      response_body = post_request("#{@server_url}/com.atproto.server.createSession", body: body, auth_token: false)

      process_tokens(response_body)
      store_token_data(response_body)
    end

    # Regenerates expired tokens with the refresh token.
    def perform_token_refresh
      response_body = post_request("#{@server_url}/com.atproto.server.refreshSession", auth_token: @renewal_token)

      process_tokens(response_body)
      store_token_data(response_body)
    end

    # Makes sure a token is set and the token has not expired.
    # If this is the first request, we'll generate the token.
    # If the token expired, we'll refresh it.
    def verify_tokens
      if @token.nil?
        generate_tokens
      elsif @token_expires_at < Time.now.utc + 60
        perform_token_refresh
      end
    end

    # Given the response body of generating or refreshing token, this pulls out
    # and stores the bits of information we care about.
    def process_tokens(response_body)
      @token = response_body["accessJwt"]
      @renewal_token = response_body["refreshJwt"]
      @user_did = response_body["did"]
      @token_expires_at = Time.at(JSON.parse(Base64.decode64(response_body["accessJwt"].split(".")[1]))["exp"]).utc
    end

    # Stores the token info for use later, else we'll have to generate the token
    # for every instance of this class.
    # Assumes the cached info is stored in the Rails cache store.
    def store_token_data(data)
      Rails.cache.write(TOKEN_CACHE_KEY, data)
    end

    def upload_image_embed(attachable)
      Rails.logger.info "Bluesky: upload_image_embed called with attachable: #{attachable.class}"
      return nil unless attachable

      begin
        blob_data = nil
        filename = "image.jpg"
        content_type = "image/jpeg"

        # Handle ActiveStorage::Blob
        if attachable.is_a?(ActiveStorage::Blob) && attachable.content_type&.start_with?("image/")
          Rails.logger.info "Bluesky: Processing ActiveStorage::Blob"
          blob_data = upload_blob(attachable)
          filename = attachable.filename.to_s if attachable.respond_to?(:filename)
        # Handle RemoteImage
        elsif attachable.class.name == "ActionText::Attachables::RemoteImage"
          Rails.logger.info "Bluesky: Processing RemoteImage"
          image_url = attachable.try(:url)
          Rails.logger.info "Bluesky: RemoteImage URL = #{image_url}"

          if image_url.present?
            blob_data = upload_remote_image(image_url)
            # Safely extract filename from URL
            begin
              filename = File.basename(URI.parse(image_url).path)
              # Ensure we have a valid filename
              filename = "image.jpg" if filename.blank? || filename == "/"
            rescue URI::InvalidURIError => e
              Rails.logger.warn "Bluesky: Invalid URL for filename extraction: #{image_url}, using default"
              filename = "image.jpg"
            end
          else
            Rails.logger.warn "Bluesky: RemoteImage has no URL, skipping"
            return nil
          end
        else
          Rails.logger.warn "Bluesky: Unknown attachable type: #{attachable.class}"
          return nil
        end

        Rails.logger.info "Bluesky: upload blob_data result: #{blob_data.present? ? 'success' : 'failed'}"
        return nil unless blob_data

        # 创建图片embed
        embed_result = {
          "$type" => "app.bsky.embed.images",
          "images" => [
            {
              "alt" => filename,
              "image" => blob_data
            }
          ]
        }
        Rails.logger.info "Bluesky: Created embed structure successfully"
        embed_result
      rescue => e
        Rails.logger.error "Error creating image embed for Bluesky: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    def upload_blob(blob)
      return nil unless blob

      begin
        # 确保token有效
        verify_tokens

        # 下载图片数据
        image_data = blob.download

        uri = URI("#{@server_url}/com.atproto.repo.uploadBlob")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = blob.content_type
        request["Authorization"] = "Bearer #{@token}"
        request.body = image_data

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          result["blob"]
        else
          Rails.logger.error "Failed to upload blob to Bluesky: #{response.code} - #{response.body}"
          nil
        end
      rescue => e
        Rails.logger.error "Error uploading blob to Bluesky: #{e.message}"
        nil
      end
    end

    def upload_remote_image(image_url)
      return nil unless image_url.present?

      begin
        # 确保token有效
        verify_tokens

        # 将相对 URL 转换为绝对 URL
        if image_url.start_with?("/")
          site_url = Setting.first&.url.presence || "http://localhost:3000"
          image_url = "#{site_url}#{image_url}"
        end

        # 下载远程图片，支持重定向（ActiveStorage redirect URLs)
        uri = URI.parse(image_url)
        image_response = fetch_with_redirect(uri)

        unless image_response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "Failed to download remote image: #{image_response.code}"
          return nil
        end

        image_data = image_response.body
        content_type = image_response["content-type"] || "image/jpeg"

        # 上传到 Bluesky
        upload_uri = URI("#{@server_url}/com.atproto.repo.uploadBlob")
        request = Net::HTTP::Post.new(upload_uri)
        request["Content-Type"] = content_type
        request["Authorization"] = "Bearer #{@token}"
        request.body = image_data

        response = Net::HTTP.start(upload_uri.hostname, upload_uri.port, use_ssl: upload_uri.scheme == "https") do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          Rails.logger.info "Bluesky: Successfully uploaded remote image to Bluesky"
          result["blob"]
        else
          Rails.logger.error "Failed to upload remote image to Bluesky: #{response.code} - #{response.body}"
          nil
        end
      rescue => e
        Rails.logger.error "Error uploading remote image to Bluesky: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    # 跟随HTTP重定向获取图片
    def fetch_with_redirect(uri, limit = 5)
      raise "Too many HTTP redirects" if limit == 0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ""))
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response["location"])
        # 如果是相对URL，补全域名
        if redirect_uri.relative?
          redirect_uri = URI.join("#{uri.scheme}://#{uri.host}:#{uri.port}", response["location"])
        end
        Rails.logger.info "Bluesky: Following redirect to #{redirect_uri}"
        fetch_with_redirect(redirect_uri, limit - 1)
      else
        response
      end
    end

    # Extract AT-URI from Bluesky URL
    # URL format: https://bsky.app/profile/{handle}/post/{rkey}
    # AT-URI format: at://{did}/app.bsky.feed.post/{rkey}
    def extract_post_uri_from_url(url)
      # Extract handle and rkey from URL
      match = url.match(%r{bsky\.app/profile/([^/]+)/post/(\w+)})
      return nil unless match

      handle = match[1]
      rkey = match[2]

      # Resolve handle to DID
      begin
        resolve_uri = URI("https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle")
        resolve_uri.query = URI.encode_www_form(handle: handle)

        response = Net::HTTP.get_response(resolve_uri)
        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          did = result["did"]
          "at://#{did}/app.bsky.feed.post/#{rkey}"
        else
          Rails.logger.error "Failed to resolve Bluesky handle: #{handle}"
          nil
        end
      rescue => e
        Rails.logger.error "Error resolving Bluesky handle: #{e.message}"
        nil
      end
    end

    # Flatten nested thread replies into a flat comment list, preserving parent relationships
    def flatten_thread_replies(replies, parent_external_id = nil)
      [].tap do |comments|
        replies.each do |reply_item|
          next unless reply_item["post"]  # Skip non-post items

          post = reply_item["post"]
          current_external_id = post["uri"].split("/").last  # Extract rkey from AT-URI

          # Add this reply as a comment with parent information
          comments << {
            external_id: current_external_id,
            author_name: post["author"]["displayName"].presence || post["author"]["handle"],
            author_username: post["author"]["handle"],
            author_avatar_url: post["author"]["avatar"],
            content: post["record"]["text"],
            published_at: Time.parse(post["record"]["createdAt"]),
            url: "https://bsky.app/profile/#{post["author"]["handle"]}/post/#{current_external_id}",
            parent_external_id: parent_external_id
          }

          # Recursively process nested replies, passing current reply as parent
          if reply_item["replies"]&.any?
            nested_comments = flatten_thread_replies(reply_item["replies"], current_external_id)
            comments.concat(nested_comments)
          end
        end
      end
    end

    # Parse rate limit headers from Bluesky API response
    def parse_rate_limit_headers(response)
      {
        limit: response["RateLimit-Limit"]&.to_i,
        remaining: response["RateLimit-Remaining"]&.to_i,
        reset_at: response["RateLimit-Reset"] ? Time.at(response["RateLimit-Reset"].to_i) : nil
      }
    end

    # Log rate limit status for monitoring
    def log_rate_limit_status(rate_limit_info)
      return unless rate_limit_info[:remaining]

      # Bluesky has higher limits (3000/5min vs Mastodon 300/5min)
      # So we use different thresholds
      if rate_limit_info[:remaining] < 100
        Rails.logger.warn "⚠️  Bluesky API rate limit low: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining (resets at #{rate_limit_info[:reset_at]})"

        ActivityLog.create!(
          action: "warning",
          target: "bluesky_api",
          level: :warning,
          description: "Bluesky API rate limit low: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining"
        )
      elsif rate_limit_info[:remaining] < 500
        Rails.logger.info "Bluesky API rate limit: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining"
      end
    end

    # Handle rate limit exceeded (429 response)
    def handle_rate_limit_exceeded(rate_limit_info)
      reset_time = rate_limit_info[:reset_at] || Time.current + 5.minutes
      wait_seconds = [ (reset_time - Time.current).to_i, 0 ].max

      Rails.logger.error "🚫 Bluesky API rate limit exceeded. Resets at #{reset_time} (in #{wait_seconds} seconds)"

      ActivityLog.create!(
        action: "rate_limited",
        target: "bluesky_api",
        level: :error,
        description: "Bluesky API rate limit exceeded. Waiting until #{reset_time}"
      )
    end
  end
end
