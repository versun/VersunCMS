require "x"
module Integrations
  class TwitterService
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
      tweet = build_content(article.slug, article.title, article.content.body.to_plain_text, article.description)
      
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
        
        response = client.post("tweets", tweet_data.to_json)

        id = response["data"]["id"] if response && response["data"] && response["data"]["id"]
        ActivityLog.create!(
          action: "crosspost",
          target: "crosspost",
          level: :info,
          description: "Successfully posted article #{article.title} to Twitter"
        )

        "https://x.com/#{username}/status/#{id}" if username && id
      rescue => e
        ActivityLog.create!(
          action: "crosspost",
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

    def build_content(slug, title, content_text, description_text = nil)
      post_url = "\nRead more:#{build_post_url(slug)}"
      max_length = 280 - 34 # URL固定23个字符+11个"\nRead more:"字符

      content_text = description_text.presence || content_text

      if count_chars(title) >= max_length - 3 # 减3是为了预留"..."的空间
        # 标题过长时，只显示标题（截断）和URL
        "#{title[0...(max_length - 3)]}...#{post_url}"
      else
        # 标题未超长时，计算剩余空间给正文内容
        remaining_length = max_length - count_chars(title) - 1 # 减1是为了标题后的换行符
        content_part = if remaining_length > 4 # 确保至少有空间放"..."
          "\n#{truncate_twitter_text(content_text, remaining_length - 3)}..."
        else
          ""
        end

        "#{title}#{content_part}#{post_url}"
      end
    end

    def count_chars(str)
      str.each_char.map { |c| c.ascii_only? ? 1 : 2 }.sum
    end

    def truncate_twitter_text(str, max_length)
      current_length = 0
      chars = []

      str.each_char do |c|
        char_length = c.ascii_only? ? 1 : 2
        break if current_length + char_length > max_length
        current_length += char_length
        chars << c
      end

      chars.join("")
    end

    def build_post_url(slug)
      Rails.application.routes.url_helpers.article_url(
        slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end

    def upload_image(client, blob)
      return nil unless blob&.content_type&.start_with?('image/')
      
      begin
        # 下载图片数据
        image_data = blob.download
        
        # 创建临时文件
        temp_file = Tempfile.new(['image', File.extname(blob.filename.to_s)])
        temp_file.binmode
        temp_file.write(image_data)
        temp_file.rewind
        
        # 上传图片到Twitter
        response = client.post("media/upload", {
          media: temp_file,
          media_type: blob.content_type
        })
        
        temp_file.close
        temp_file.unlink
        
        response["media_id_string"] if response && response["media_id_string"]
      rescue => e
        Rails.logger.error "Error uploading image to Twitter: #{e.message}"
        nil
      end
    end
  end
end
