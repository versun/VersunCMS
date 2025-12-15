require "x"
require "tempfile"
require "net/http"
require "uri"
require "json"
module Integrations
  class TwitterService
    include ContentBuilder

    def initialize
      @settings = Crosspost.twitter
    end

    def verify(settings)
      if settings[:access_token_secret].blank? || settings[:access_token].blank? || settings[:api_key].blank? || settings[:api_key_secret].blank?
        return { success: false, error: "Please fill in all information" }
      end

      begin
          client = X::Client.new(
            api_key: settings[:api_key],
            api_key_secret: settings[:api_key_secret],
            access_token: settings[:access_token],
            access_token_secret: settings[:access_token_secret]
          )

          # Try to post a test tweet to verify credentials
          test_response = client.get("users/me")
          if test_response && test_response["data"] && test_response["data"]["id"]
            { success: true }
          else
            { success: false, error: "Twitter verification failed: #{test_response}" }
          end

      rescue => e
        { success: false, error: "Twitter verification failed: #{e.message}" }
      end
    end

    def post(article)
      return unless @settings&.enabled?

      client = create_client
      max_length = @settings.effective_max_characters || 250
      tweet = build_content(article.slug, article.title, article.plain_text_content, article.description, max_length: max_length, count_non_ascii_double: true)

      begin
        user = client.get("users/me")
        username = user["data"]["username"] if user && user["data"]

        # 获取文章第一张图片
        first_image = article.first_image_attachment
        Rails.logger.info "Twitter: first_image_attachment = #{first_image.class}"

        media_ids = []
        if first_image
          Rails.logger.info "Twitter: Attempting to upload image of type: #{first_image.class}"
          media_id = upload_image(client, first_image)
          if media_id
            media_ids << media_id
            Rails.logger.info "Twitter: Image uploaded successfully with media_id: #{media_id}"
          else
            Rails.logger.warn "Twitter: Image upload failed"
          end
        else
          Rails.logger.info "Twitter: No image found in article"
        end

        # 构建推文数据
        tweet_data = { text: tweet }
        if media_ids.any?
          tweet_data[:media] = {
            media_ids: media_ids.map(&:to_s)
          }
        end

        Rails.logger.info "Twitter: Sending tweet with data: #{tweet_data.inspect}"
        response = client.post("tweets", tweet_data.to_json)

        if response && response["data"] && response["data"]["id"]
          id = response["data"]["id"]
          ActivityLog.create!(
            action: "completed",
            target: "crosspost",
            level: :info,
            description: "Successfully posted article #{article.title} to Twitter"
          )
        else
          error_message = response&.dig("errors")&.first&.dig("message") || "Unknown error"
          Rails.logger.error "Twitter: Failed to create tweet - #{error_message}"

          # 如果带媒体的推文失败，尝试发送纯文本推文
          if media_ids.any? && error_message.include?("media")
            Rails.logger.warn "Twitter: Media tweet failed, trying text-only tweet"

            text_only_data = { text: tweet }
            Rails.logger.info "Twitter: Sending text-only tweet: #{text_only_data.inspect}"

            begin
              fallback_response = client.post("tweets", text_only_data.to_json)

              if fallback_response && fallback_response["data"] && fallback_response["data"]["id"]
                id = fallback_response["data"]["id"]
                Rails.logger.warn "Twitter: Text-only tweet succeeded, media was skipped"

                ActivityLog.create!(
                  action: "completed",
                  target: "crosspost",
                  level: :warning,
                  description: "Posted article #{article.title} to Twitter (text only, media skipped due to API limitations)"
                )
              else
                raise "Fallback text tweet also failed"
              end
            rescue => fallback_error
              Rails.logger.error "Twitter: Fallback text tweet also failed - #{fallback_error.message}"

              ActivityLog.create!(
                action: "failed",
                target: "crosspost",
                level: :error,
                description: "Failed to post article #{article.title} to Twitter: #{error_message} (and fallback also failed)"
              )
              return nil
            end
          else
            ActivityLog.create!(
              action: "failed",
              target: "crosspost",
              level: :error,
              description: "Failed to post article #{article.title} to Twitter: #{error_message}"
            )
            return nil
          end
        end

        "https://x.com/#{username}/status/#{id}" if username && id
      rescue => e
        Rails.logger.error "Twitter: Error posting tweet - #{e.message}"
        ActivityLog.create!(
          action: "failed",
          target: "crosspost",
          level: :error,
          description: "Failed to post article #{article.title} to X: #{e.message}"
        )
        nil
      end
    end

    # Fetch comments (replies and quote tweets) for a Twitter/X post
    # Returns a hash with :comments array and :rate_limit info
    def fetch_comments(post_url)
      default_response = { comments: [], rate_limit: nil }
      return default_response unless @settings&.enabled?
      return default_response if post_url.blank?

      begin
        # Extract tweet ID from URL
        tweet_id = extract_tweet_id_from_url(post_url)
        return default_response unless tweet_id

        client = create_client

        # Use Twitter API v2 to get conversation thread
        # Note: Free tier has limited access, using conversation_id lookup
        response = make_rate_limited_request(client, "tweets/#{tweet_id}?expansions=author_id,referenced_tweets.id&tweet.fields=conversation_id,created_at,author_id&user.fields=username,name,profile_image_url")

        if response && response["data"]
          conversation_id = response["data"]["conversation_id"]
          comments = []
          rate_limit_info = nil

          # 1. Get direct replies to the original tweet
          replies_query = "conversation_id:#{conversation_id} is:reply"
          replies_response, rate_limit_info = make_rate_limited_request_with_retry(
            client,
            "tweets/search/recent?query=#{CGI.escape(replies_query)}&expansions=author_id,referenced_tweets.id&tweet.fields=created_at,referenced_tweets,conversation_id&user.fields=username,name,profile_image_url&max_results=100"
          )

          if replies_response
            comments.concat(process_tweets(replies_response, tweet_id))
          end

          # 2. Get quote tweets (转帖) that quote the original tweet
          # Note: Twitter API v2 free tier may have limited support for quote tweet search
          quote_tweets = []

          begin
            # Try searching for quote tweets using URL
            # This method may not work on all API tiers, so we wrap it in error handling
            quote_query = "url:#{CGI.escape(post_url)} is:quote"
            quote_response, rate_limit_info = make_rate_limited_request_with_retry(
              client,
              "tweets/search/recent?query=#{CGI.escape(quote_query)}&expansions=author_id,referenced_tweets.id&tweet.fields=created_at,referenced_tweets,conversation_id&user.fields=username,name,profile_image_url&max_results=100"
            )

            if quote_response && quote_response["data"]
              quote_tweets = process_tweets(quote_response, tweet_id)
              Rails.logger.info "Found #{quote_tweets.length} quote tweets for tweet #{tweet_id}"
            end
          rescue => e
            Rails.logger.warn "Failed to fetch quote tweets (may require higher API tier): #{e.message}"
            # Continue without quote tweets - we can still fetch direct replies
          end

          comments.concat(quote_tweets)

          # 3. For each quote tweet, get its replies
          quote_tweets.each do |quote_tweet|
            quote_tweet_id = quote_tweet[:external_id]
            quote_conversation_id = quote_tweet[:conversation_id]

            if quote_conversation_id
              quote_replies_query = "conversation_id:#{quote_conversation_id} is:reply"
              quote_replies_response, rate_limit_info = make_rate_limited_request_with_retry(
                client,
                "tweets/search/recent?query=#{CGI.escape(quote_replies_query)}&expansions=author_id,referenced_tweets.id&tweet.fields=created_at,referenced_tweets,conversation_id&user.fields=username,name,profile_image_url&max_results=100"
              )

              if quote_replies_response
                quote_replies = process_tweets(quote_replies_response, quote_tweet_id)
                comments.concat(quote_replies)
              end
            end
          end

          # Use the last known rate limit info, or create default
          rate_limit_info ||= {
            limit: nil,
            remaining: nil,
            reset_at: nil
          }

          { comments: comments, rate_limit: rate_limit_info }
        else
          Rails.logger.error "Failed to fetch Twitter post details: #{response.inspect}"
          default_response
        end
      rescue => e
        Rails.logger.error "Error fetching Twitter comments: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        default_response
      end
    end

    # Process tweets from API response and convert to comment format
    def process_tweets(search_response, parent_tweet_id)
      comments = []
      return comments unless search_response && search_response["data"]

      users_map = {}
      if search_response["includes"] && search_response["includes"]["users"]
        search_response["includes"]["users"].each do |user|
          users_map[user["id"]] = user
        end
      end

      # Build a map of referenced tweets for parent lookup
      referenced_tweets_map = {}
      if search_response["includes"] && search_response["includes"]["tweets"]
        search_response["includes"]["tweets"].each do |ref_tweet|
          referenced_tweets_map[ref_tweet["id"]] = ref_tweet
        end
      end

      search_response["data"].each do |tweet|
        author = users_map[tweet["author_id"]]
        next unless author

        # Find parent external_id from referenced_tweets
        parent_external_id = nil
        if tweet["referenced_tweets"]
          replied_to = tweet["referenced_tweets"].find { |ref| ref["type"] == "replied_to" }
          parent_external_id = replied_to["id"] if replied_to

          # If no replied_to, check if it's a quote tweet
          if parent_external_id.nil?
            quoted = tweet["referenced_tweets"].find { |ref| ref["type"] == "quoted" }
            parent_external_id = quoted["id"] if quoted
          end
        end

        # Use the provided parent_tweet_id if no parent found in referenced_tweets
        parent_external_id ||= parent_tweet_id

        comment_data = {
          external_id: tweet["id"],
          author_name: author["name"],
          author_username: author["username"],
          author_avatar_url: author["profile_image_url"],
          content: tweet["text"],
          published_at: Time.parse(tweet["created_at"]),
          url: "https://x.com/#{author["username"]}/status/#{tweet["id"]}",
          parent_external_id: parent_external_id
        }

        # Store conversation_id for quote tweets so we can fetch their replies
        if tweet["conversation_id"]
          comment_data[:conversation_id] = tweet["conversation_id"]
        end

        comments << comment_data
      end

      comments
    end

    private

    def create_client
      X::Client.new(
        api_key: @settings.api_key,
        api_key_secret: @settings.api_key_secret,
        access_token: @settings.access_token,
        access_token_secret: @settings.access_token_secret
      )
    end

    def create_v1_client
      # 为媒体上传创建 v1.1 客户端
      X::Client.new(
        api_key: @settings.api_key,
        api_key_secret: @settings.api_key_secret,
        access_token: @settings.access_token,
        access_token_secret: @settings.access_token_secret,
        base_url: "https://upload.twitter.com/1.1/"
      )
    end

    def upload_image(client, attachable)
      return nil unless attachable

      begin
        # 创建临时文件来存储图片数据
        temp_file = create_temp_image_file(attachable)
        return nil unless temp_file

        # 使用 Twitter API v1.1 上传媒体
        media_id = upload_media_to_twitter(client, temp_file.path)

        # 清理临时文件
        temp_file.close
        temp_file.unlink

        media_id
      rescue => e
        Rails.logger.error "Twitter: Error uploading image - #{e.message}"
        nil
      end
    end

    def upload_media_to_twitter(client, file_path)
      return nil unless File.exist?(file_path)

      # 使用 Twitter API v1.1 上传媒体
      # 注意：需要使用 v1.1 端点进行媒体上传
      v1_client = create_v1_client

      # 使用简单的媒体上传（非分块上传）
      begin
        # 读取文件数据
        file_data = File.binread(file_path)

        # 创建 multipart/form-data 请求
        boundary = SecureRandom.hex
        upload_body = construct_upload_body(file_path, boundary)

        headers = {
          "Content-Type" => "multipart/form-data; boundary=#{boundary}",
          "Authorization" => build_oauth_header("POST", "https://upload.twitter.com/1.1/media/upload.json")
        }

        # 使用 v1.1 上传端点
        response = v1_client.post("media/upload.json", upload_body, headers: headers)

        Rails.logger.info "Twitter: Media upload response - #{response.inspect}"

        if response && (response["media_id"] || response["media_id_string"])
          media_id = response["media_id_string"] || response["media_id"].to_s
          Rails.logger.info "Twitter: Media uploaded successfully with ID: #{media_id}"
          media_id
        else
          Rails.logger.error "Twitter: Media upload failed - #{response.inspect}"
          nil
        end
      rescue => e
        Rails.logger.error "Twitter: Error in upload_media_to_twitter - #{e.message}"
        Rails.logger.error "Twitter: Error backtrace - #{e.backtrace.first(5).join("\n")}"
        nil
      end
    end

    def create_temp_image_file(attachable)
      return nil unless attachable

      begin
        image_data = case attachable
        when ActiveStorage::Blob
          attachable.download if attachable.content_type&.start_with?("image/")
        when ->(obj) { obj.class.name == "ActionText::Attachables::RemoteImage" }
          download_remote_image(attachable)
        else
          nil
        end

        return nil unless image_data

        # 创建临时文件
        temp_file = Tempfile.new([ "twitter_image", ".jpg" ], binmode: true)
        temp_file.write(image_data)
        temp_file.rewind
        temp_file
      rescue => e
        Rails.logger.error "Twitter: Error creating temp image file - #{e.message}"
        nil
      end
    end

    def download_remote_image(remote_image)
      return nil unless remote_image.respond_to?(:url)

      image_url = remote_image.url
      return nil unless image_url.present?

      # 处理相对URL
      if image_url.start_with?("/")
        site_url = Setting.first&.url.presence || "http://localhost:3000"
        image_url = "#{site_url}#{image_url}"
      end

      # 下载图片，支持重定向
      uri = URI.parse(image_url)
      response = fetch_with_redirect(uri)

      if response.is_a?(Net::HTTPSuccess)
        response.body
      else
        Rails.logger.error "Twitter: Failed to download remote image: #{response.code}"
        nil
      end
    rescue => e
      Rails.logger.error "Twitter: Error downloading remote image - #{e.message}"
      nil
    end

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
        # 处理相对URL重定向
        if redirect_uri.relative?
          redirect_uri = URI.join("#{uri.scheme}://#{uri.host}:#{uri.port}", response["location"])
        end
        Rails.logger.info "Twitter: Following redirect to #{redirect_uri}"
        fetch_with_redirect(redirect_uri, limit - 1)
      else
        response
      end
    end

    # Build OAuth 1.0a authorization header for Twitter API
    def build_oauth_header(method, url, params = {})
      require "openssl"
      require "base64"
      require "cgi"

      oauth_params = {
        "oauth_consumer_key" => @settings.api_key,
        "oauth_token" => @settings.access_token,
        "oauth_signature_method" => "HMAC-SHA1",
        "oauth_timestamp" => Time.now.to_i.to_s,
        "oauth_nonce" => SecureRandom.hex(16),
        "oauth_version" => "1.0"
      }

      # Combine OAuth and request parameters
      all_params = oauth_params.merge(params)

      # Create signature base string
      sorted_params = all_params.sort.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
      base_string = "#{method.upcase}&#{CGI.escape(url)}&#{CGI.escape(sorted_params)}"

      # Create signing key
      signing_key = "#{CGI.escape(@settings.api_key_secret)}&#{CGI.escape(@settings.access_token_secret)}"

      # Generate signature
      signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", signing_key, base_string))
      oauth_params["oauth_signature"] = signature

      # Build header
      header_params = oauth_params.sort.map { |k, v| "#{k}=\"#{CGI.escape(v.to_s)}\"" }.join(", ")
      "OAuth #{header_params}"
    end

    def construct_upload_body(file_path, boundary)
      file_data = File.binread(file_path)
      filename = File.basename(file_path)
      media_category = "tweet_image"

      "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"media_category\"\r\n\r\n" \
        "#{media_category}\r\n" \
        "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"media\"; filename=\"#{filename}\"\r\n" \
        "Content-Type: image/jpeg\r\n\r\n" \
        "#{file_data}\r\n" \
        "--#{boundary}--\r\n"
    end

    def check_media_status(client, media_id)
      # 简化媒体状态检查 - 由于API限制，我们假设上传的媒体是可用的
      # 实际的状态检查可能需要更高级的API访问权限
      return true unless media_id

      Rails.logger.info "Twitter: Skipping detailed media status check due to API limitations"
      true
    end

    # Extract tweet ID from Twitter/X URL
    # Supports formats:
    # - https://twitter.com/username/status/1234567890
    # - https://x.com/username/status/1234567890
    def extract_tweet_id_from_url(url)
      match = url.match(%r{(?:twitter\.com|x\.com)/\w+/status/(\d+)})
      match ? match[1] : nil
    end

    # Make a rate-limited API request with delay between requests
    # Twitter API v2 limits:
    # - GET /2/tweets/:id: 300 requests per 15 minutes (20 RPM)
    # - GET /2/tweets/search/recent: 180 requests per 15 minutes (12 RPM)
    # We use conservative 10 RPM (6 seconds between requests)
    def make_rate_limited_request(client, endpoint, max_retries: 3)
      retries = 0
      delay_between_requests = 6 # seconds - conservative 10 RPM limit

      begin
        # Add delay before request (except first request)
        if @last_request_time
          elapsed = Time.current - @last_request_time
          if elapsed < delay_between_requests
            sleep(delay_between_requests - elapsed)
          end
        end

        response = client.get(endpoint)
        @last_request_time = Time.current

        # Check for rate limit in response (X gem may include this in response)
        if response.is_a?(Hash) && response["errors"]
          error = response["errors"].first
          if error && (error["title"]&.include?("Too Many Requests") || error["detail"]&.include?("Too Many Requests"))
            raise "Rate limit exceeded: #{error["detail"] || error["title"]}"
          end
        end

        response
      rescue => e
        error_message = e.message.to_s
        if error_message.include?("Too Many Requests") || error_message.include?("Rate limit") || error_message.include?("429")
          retries += 1
          if retries <= max_retries
            wait_time = calculate_backoff_time(retries)
            Rails.logger.warn "Twitter API rate limit hit, waiting #{wait_time} seconds before retry #{retries}/#{max_retries}"
            sleep(wait_time)
            retry
          else
            Rails.logger.error "Twitter API rate limit exceeded after #{max_retries} retries"
            handle_rate_limit_exceeded({
              limit: 180,
              remaining: 0,
              reset_at: Time.current + 15.minutes
            })
            raise
          end
        else
          raise
        end
      end
    end

    # Make a rate-limited request with retry logic and return rate limit info
    def make_rate_limited_request_with_retry(client, endpoint, max_retries: 3)
      retries = 0
      delay_between_requests = 6 # seconds - conservative 10 RPM limit

      begin
        # Add delay before request (except first request)
        if @last_request_time
          elapsed = Time.current - @last_request_time
          if elapsed < delay_between_requests
            sleep(delay_between_requests - elapsed)
          end
        end

        response = client.get(endpoint)
        @last_request_time = Time.current

        # Check for rate limit errors
        if response.is_a?(Hash) && response["errors"]
          error = response["errors"].first
          if error && (error["title"]&.include?("Too Many Requests") || error["detail"]&.include?("Too Many Requests"))
            raise "Rate limit exceeded: #{error["detail"] || error["title"]}"
          end
        end

        # Try to extract rate limit info from response
        # Note: X gem may not expose headers directly, so we estimate based on API limits
        rate_limit_info = {
          limit: 180, # Twitter search API limit per 15 minutes
          remaining: nil, # X gem may not expose this
          reset_at: Time.current + 15.minutes # Reset window is 15 minutes
        }

        [ response, rate_limit_info ]
      rescue => e
        error_message = e.message.to_s
        if error_message.include?("Too Many Requests") || error_message.include?("Rate limit") || error_message.include?("429")
          retries += 1
          if retries <= max_retries
            wait_time = calculate_backoff_time(retries)
            Rails.logger.warn "Twitter API rate limit hit, waiting #{wait_time} seconds before retry #{retries}/#{max_retries}"

            # Log rate limit exceeded
            handle_rate_limit_exceeded({
              limit: 180,
              remaining: 0,
              reset_at: Time.current + wait_time
            })

            sleep(wait_time)
            retry
          else
            Rails.logger.error "Twitter API rate limit exceeded after #{max_retries} retries"
            handle_rate_limit_exceeded({
              limit: 180,
              remaining: 0,
              reset_at: Time.current + 15.minutes
            })
            [ nil, { limit: 180, remaining: 0, reset_at: Time.current + 15.minutes } ]
          end
        else
          raise
        end
      end
    end

    # Calculate exponential backoff time for retries
    def calculate_backoff_time(retry_count)
      # Exponential backoff: 15s, 30s, 60s
      base_wait = 15
      [ base_wait * (2 ** (retry_count - 1)), 300 ].min # Cap at 5 minutes
    end

    # Handle rate limit exceeded (429 response)
    def handle_rate_limit_exceeded(rate_limit_info)
      reset_time = rate_limit_info[:reset_at] || Time.current + 15.minutes
      wait_seconds = [ (reset_time - Time.current).to_i, 0 ].max

      Rails.logger.error "🚫 Twitter API rate limit exceeded. Resets at #{reset_time} (in #{wait_seconds} seconds)"

      ActivityLog.create!(
        action: "rate_limited",
        target: "twitter_api",
        level: :error,
        description: "Twitter API rate limit exceeded. Waiting until #{reset_time}"
      )
    end

    # Log rate limit status for monitoring
    def log_rate_limit_status(rate_limit_info)
      return unless rate_limit_info[:remaining]

      if rate_limit_info[:remaining] < 20
        Rails.logger.warn "⚠️  Twitter API rate limit low: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining (resets at #{rate_limit_info[:reset_at]})"

        ActivityLog.create!(
          action: "warning",
          target: "twitter_api",
          level: :warning,
          description: "Twitter API rate limit low: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining"
        )
      elsif rate_limit_info[:remaining] < 50
        Rails.logger.info "Twitter API rate limit: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining"
      end
    end
  end
end
