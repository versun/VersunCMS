require "x"
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
      tweet = build_content(article.slug, article.title, article.content.body.to_plain_text, article.description, max_length: 280, count_non_ascii_double: true)

      # 获取文章第一张图片
      first_image = article.first_image_attachment
      media_ids = []

      if first_image
        media_id = upload_image(client, first_image)
        media_ids << media_id if media_id
      end

      begin
        user = client.get("users/me")
        username = user["data"]["username"] if user && user["data"]

        tweet_data = { text: tweet }
        tweet_data[:media] = { media_ids: media_ids } if media_ids.any?

        Rails.logger.info "Twitter: Sending tweet with data: #{tweet_data.inspect}"
        response = client.post("tweets", tweet_data.to_json)

        id = response["data"]["id"] if response && response["data"] && response["data"]["id"]
        ActivityLog.create!(
          action: "completed",
          target: "crosspost",
          level: :info,
          description: "Successfully posted article #{article.title} to Twitter"
        )

        "https://x.com/#{username}/status/#{id}" if username && id
      rescue => e
        Rails.logger.error "Twitter: Error posting tweet - #{e.class}: #{e.message}"
        Rails.logger.error "Twitter: Error backtrace: #{e.backtrace.first(5).join("\n")}"
        ActivityLog.create!(
          action: "failed",
          target: "crosspost",
          level: :error,
          description: "Failed to post article #{article.title} to X: #{e.message}"
        )
        nil
      end
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

    # Build OAuth 1.0a authorization header for Twitter API
    def build_oauth_header(method, url, params = {})
      require 'openssl'
      require 'base64'
      
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

    def upload_image(client, attachable)
      Rails.logger.info "Twitter: upload_image called with attachable: #{attachable.class}"
      return nil unless attachable

      begin
        image_data = nil
        filename = "image.jpg"
        content_type = "image/jpeg"
        
        # Handle ActiveStorage::Blob
        if attachable.is_a?(ActiveStorage::Blob) && attachable.content_type&.start_with?("image/")
          Rails.logger.info "Twitter: Processing ActiveStorage::Blob"
          image_data = attachable.download
          filename = attachable.filename.to_s if attachable.respond_to?(:filename)
          content_type = attachable.content_type
        # Handle RemoteImage
        elsif attachable.class.name == "ActionText::Attachables::RemoteImage"
          Rails.logger.info "Twitter: Processing RemoteImage"
          image_url = attachable.try(:url)
          Rails.logger.info "Twitter: RemoteImage URL = #{image_url}"
          
          if image_url.present?
            # Download remote image
            image_data, content_type = download_remote_image(image_url)
            # Safely extract filename from URL
            begin
              filename = File.basename(URI.parse(image_url).path)
              # Ensure we have a valid filename
              filename = "image.jpg" if filename.blank? || filename == "/"
            rescue URI::InvalidURIError => e
              Rails.logger.warn "Twitter: Invalid URL for filename extraction: #{image_url}, using default"
              filename = "image.jpg"
            end
          else
            Rails.logger.warn "Twitter: RemoteImage has no URL, skipping"
            return nil
          end
        else
          Rails.logger.warn "Twitter: Unknown attachable type: #{attachable.class}"
          return nil
        end
        
        return nil unless image_data

        # 上传图片到Twitter使用multipart form-data
        uri = URI("https://upload.twitter.com/1.1/media/upload.json")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        
        # OAuth 1.0a authentication headers
        request["Authorization"] = build_oauth_header("POST", uri.to_s, {})
        
        # 创建multipart表单数据
        boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

        # 构建 multipart 表单数据
        body_parts = []
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"media\"; filename=\"#{filename}\"\r\n"
        body_parts << "Content-Type: #{content_type}\r\n\r\n"
        body_parts << image_data
        body_parts << "\r\n--#{boundary}--\r\n"

        # 将所有部分强制转换为 ASCII-8BIT 编码并连接
        request.body = body_parts.map { |part| part.force_encoding("ASCII-8BIT") }.join

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          media_data = JSON.parse(response.body)
          Rails.logger.info "Twitter: Successfully uploaded image to Twitter"
          media_data["media_id_string"]
        else
          Rails.logger.error "Failed to upload image to Twitter: #{response.code} - #{response.body}"
          nil
        end
      rescue => e
        Rails.logger.error "Error uploading image to Twitter: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    # Download remote image with redirect support
    def download_remote_image(image_url)
      return nil unless image_url.present?

      begin
        # 将相对 URL 转换为绝对 URL
        if image_url.start_with?('/')
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
        
        [image_data, content_type]
      rescue => e
        Rails.logger.error "Error downloading remote image: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    # 跟随HTTP重定向获取图片
    def fetch_with_redirect(uri, limit = 5)
      raise "Too many HTTP redirects" if limit == 0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 10
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ""))
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response['location'])
        # 如果是相对URL，补全域名
        if redirect_uri.relative?
          redirect_uri = URI.join("#{uri.scheme}://#{uri.host}:#{uri.port}", response['location'])
        end
        Rails.logger.info "Twitter: Following redirect to #{redirect_uri}"
        fetch_with_redirect(redirect_uri, limit - 1)
      else
        response
      end
    end
  end
end
