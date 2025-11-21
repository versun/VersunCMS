require "net/http"
require "uri"

module Integrations
  class MastodonService
    def initialize
      @settings = Crosspost.mastodon
    end

    def verify(settings)
      if settings[:access_token].blank?
        return { success: false, error: "Access token are required" }
      end

      begin
        uri = URI.join(settings[:server_url], "/api/v1/accounts/verify_credentials")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{settings[:access_token]}"

        response = http.request(request)

        response.is_a?(Net::HTTPSuccess) ?
          { success: true } :
          { success: false, error: "Verification failed: #{response.code} #{response.message}" }
      rescue => e
        { success: false, error: "Mastodon verification failed: #{e}" }
      end
    end


    def post(article)
      return unless @settings&.enabled?
      status_text = build_content(article.slug, article.title, article.content.body.to_plain_text, article.description)

      # 获取文章第一张图片
      first_image = article.first_image_attachment
      media_id = nil

      if first_image
        media_id = upload_image(first_image)
      end

      uri = URI.join(@settings[:server_url], "/api/v1/statuses")

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri)
        form_data = {
          status: status_text,
          visibility: "public"
        }

        # 如果有图片，添加媒体ID
        form_data[:media_ids] = [ media_id ] if media_id

        request.set_form_data(form_data)
        request["Authorization"] = "Bearer #{@settings.access_token}"

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          json_response = JSON.parse(response.body)
          ActivityLog.create!(
            action: "completed",
            target: "crosspost",
            level: :info,
            description: "Successfully posted article #{article.title} to Mastodon"
          )

          json_response["url"]
        else
          ActivityLog.create!(
            action: "failed",
            target: "crosspost",
            level: :error,
            description: "Failed to post article #{article.title} to Mastodon: #{e.message}"
          )
          nil
        end
      rescue => e
        ActivityLog.create!(
          action: "failed",
          target: "crosspost",
          level: :error,
          description: "Failed to post article #{article.title} to Mastodon: #{e.message}"
        )
        nil
      end
    end

    # Fetch comments (replies) for a Mastodon status
    # Returns a hash with :comments array and :rate_limit info
    def fetch_comments(status_url)
      default_response = { comments: [], rate_limit: nil }
      return default_response unless @settings&.enabled?
      return default_response if status_url.blank?

      begin
        # Extract status ID from URL (e.g., https://mastodon.social/@username/123456789)
        status_id = extract_status_id_from_url(status_url)
        return default_response unless status_id

        # Call Mastodon API to get context (ancestors and descendants/replies)
        uri = URI.join(@settings[:server_url], "/api/v1/statuses/#{status_id}/context")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@settings.access_token}"

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
          context_data = JSON.parse(response.body)
          descendants = context_data["descendants"] || []

          # Parse descendants into comment data
          comments = descendants.map do |reply|
            {
              external_id: reply["id"],
              author_name: reply["account"]["display_name"].presence || reply["account"]["username"],
              author_username: reply["account"]["acct"],
              author_avatar_url: reply["account"]["avatar"],
              content: reply["content"],
              published_at: Time.parse(reply["created_at"]),
              url: reply["url"]
            }
          end

          { comments: comments, rate_limit: rate_limit_info }
        else
          Rails.logger.error "Failed to fetch Mastodon comments: #{response.code} - #{response.body}"
          { comments: [], rate_limit: rate_limit_info }
        end
      rescue => e
        Rails.logger.error "Error fetching Mastodon comments: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        default_response
      end
    end

    private

    # def create_client
    #   Mastodon::REST::Client.new(
    #     base_url: @settings[:server_url],
    #     bearer_token: @settings.access_token
    #   )
    # end

    def build_content(slug, title, content_text, description_text = nil)
      post_url = build_post_url(slug)
      content_text = description_text.presence || content_text
      max_content_length = 500 - post_url.length - 30 - title.length

      "#{title}\n#{content_text[0...max_content_length]}...\nRead more: #{post_url}"
    end

    def build_post_url(slug)
      Rails.application.routes.url_helpers.article_url(
        slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end

    def upload_image(blob)
      return nil unless blob&.content_type&.start_with?("image/")

      begin
        uri = URI.join(@settings[:server_url], "/api/v2/media")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@settings.access_token}"

        # 创建multipart表单数据
        boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

        # 下载图片数据
        image_data = blob.download

        body = []
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{blob.filename}\"\r\n"
        body << "Content-Type: #{blob.content_type}\r\n\r\n"
        body << image_data
        body << "\r\n--#{boundary}--\r\n"

        request.body = body.join

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          media_data = JSON.parse(response.body)
          media_data["id"]
        else
          Rails.logger.error "Failed to upload image to Mastodon: #{response.code} - #{response.body}"
          nil
        end
      rescue => e
        Rails.logger.error "Error uploading image to Mastodon: #{e.message}"
        nil
      end
    end

    # Parse rate limit headers from Mastodon API response
    def parse_rate_limit_headers(response)
      {
        limit: response["X-RateLimit-Limit"]&.to_i,
        remaining: response["X-RateLimit-Remaining"]&.to_i,
        reset_at: response["X-RateLimit-Reset"] ? Time.at(response["X-RateLimit-Reset"].to_i) : nil
      }
    end

    # Log rate limit status for monitoring
    def log_rate_limit_status(rate_limit_info)
      return unless rate_limit_info[:remaining]

      if rate_limit_info[:remaining] < 10
        Rails.logger.warn "⚠️  Mastodon API rate limit low: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining (resets at #{rate_limit_info[:reset_at]})"

        ActivityLog.create!(
          action: "warning",
          target: "mastodon_api",
          level: :warning,
          description: "Mastodon API rate limit low: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining"
        )
      elsif rate_limit_info[:remaining] < 50
        Rails.logger.info "Mastodon API rate limit: #{rate_limit_info[:remaining]}/#{rate_limit_info[:limit]} remaining"
      end
    end

    # Handle rate limit exceeded (429 response)
    def handle_rate_limit_exceeded(rate_limit_info)
      reset_time = rate_limit_info[:reset_at] || Time.current + 5.minutes
      wait_seconds = [ (reset_time - Time.current).to_i, 0 ].max

      Rails.logger.error "🚫 Mastodon API rate limit exceeded. Resets at #{reset_time} (in #{wait_seconds} seconds)"

      ActivityLog.create!(
        action: "rate_limited",
        target: "mastodon_api",
        level: :error,
        description: "Mastodon API rate limit exceeded. Waiting until #{reset_time}"
      )
    end

    def extract_status_id_from_url(url)
      # Mastodon URLs are typically: https://mastodon.social/@username/123456789
      # or https://mastodon.social/users/username/statuses/123456789
      match = url.match(%r{/(?:@\w+|users/\w+/statuses)/(\d+)})
      match ? match[1] : nil
    end
  end
end
