module Integrations
  # COPY from: https://t27duck.com/posts/17-a-bluesky-at-proto-api-example-in-ruby
  class BlueskyService
    TOKEN_CACHE_KEY = :bluesky_token_data

    def initialize
      @settings = Crosspost.bluesky
      return unless @settings.present?

      @username = @settings.username
      @password = @settings.app_password
      @server_url = "https://bsky.social/xrpc" if @settings.server_url.blank?

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
      embed = nil

      if first_image
        embed = upload_image_embed(first_image)
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

      body = {
        repo: @user_did, collection: "app.bsky.feed.post",
        record: {
          text: message,
          createdAt: Time.now.iso8601,
          langs: [ "en" ],
          facets: facets,
          embed: embed
        }
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
        if response.code == '429'
          handle_rate_limit_exceeded(rate_limit_info)
          return { comments: [], rate_limit: rate_limit_info }
        end

        if response.is_a?(Net::HTTPSuccess)
          thread_data = JSON.parse(response.body)
          
          # Get replies from thread (nested structure)
          replies = thread_data.dig("thread", "replies") || []
          
          # Flatten nested replies into comment list
          comments = flatten_thread_replies(replies)

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

    def build_content(slug, title, content_text, description_text = nil)
      post_url = build_post_url(slug)
      content_text = description_text.presence || content_text
      max_content_length = 300 - post_url.length - 30 - title.length

      "#{title}\n#{content_text[0...max_content_length]}...\nRead more: #{post_url}"
    end

    def build_post_url(slug)
      Rails.application.routes.url_helpers.article_url(
        slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end

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
          start, stop = match.byteoffset(0)
          facets << {
            "index" => { "byteStart" => start, "byteEnd" => stop },
            "features" => [ { "uri" => match[0], "$type" => "app.bsky.richtext.facet#link" } ]
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

    def upload_image_embed(blob)
      return nil unless blob&.content_type&.start_with?("image/")

      begin
        # 上传图片获取blob
        blob_data = upload_blob(blob)
        return nil unless blob_data

        # 创建图片embed
        {
          "$type" => "app.bsky.embed.images",
          "images" => [
            {
              "alt" => blob.filename.to_s,
              "image" => blob_data
            }
          ]
        }
      rescue => e
        Rails.logger.error "Error creating image embed for Bluesky: #{e.message}"
        nil
      end
    end

    def upload_blob(blob)
      return nil unless blob

      begin
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

    # Flatten nested thread replies into a flat comment list
    def flatten_thread_replies(replies, depth = 0)
      [].tap do |comments|
        replies.each do |reply_item|
          next unless reply_item["post"]  # Skip non-post items

          post = reply_item["post"]
          
          # Add this reply as a comment
          comments << {
            external_id: post["uri"].split('/').last,  # Extract rkey from AT-URI
            author_name: post["author"]["displayName"].presence || post["author"]["handle"],
            author_username: post["author"]["handle"],
            author_avatar_url: post["author"]["avatar"],
            content: post["record"]["text"],
            published_at: Time.parse(post["record"]["createdAt"]),
            url: "https://bsky.app/profile/#{post["author"]["handle"]}/post/#{post["uri"].split('/').last}"
          }

          # Recursively process nested replies
          if reply_item["replies"]&.any?
            nested_comments = flatten_thread_replies(reply_item["replies"], depth + 1)
            comments.concat(nested_comments)
          end
        end
      end
    end

    # Parse rate limit headers from Bluesky API response
    def parse_rate_limit_headers(response)
      {
        limit: response['RateLimit-Limit']&.to_i,
        remaining: response['RateLimit-Remaining']&.to_i,
        reset_at: response['RateLimit-Reset'] ? Time.at(response['RateLimit-Reset'].to_i) : nil
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
      wait_seconds = [(reset_time - Time.current).to_i, 0].max

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
