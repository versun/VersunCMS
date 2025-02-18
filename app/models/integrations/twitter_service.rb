require "x"
module Integrations
  class TwitterService
    def initialize()
      @api_key = ENV.fetch("TWITTER_API_KEY")
      @api_key_secret = ENV.fetch("TWITTER_API_KEY_SECRET")
      @access_token = ENV.fetch("TWITTER_ACCESS_TOKEN")
      @access_token_secret = ENV.fetch("TWITTER_ACCESS_TOKEN_SECRET")
      @client = create_client
    end

    def verify()
      if @api_key.blank? || @api_key_secret.blank? || @access_token.blank?
        return { success: false, error: "Client ID, client secret, and access token are required" }
      end

      begin
          # Try to post a test tweet to verify credentials
          test_response = @client.get("users/me")
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
      tweet = build_tweet(article)

      begin
        user = @client.get("users/me")
        username = user["data"]["username"] if user && user["data"]
        response = @client.post("tweets", { text: tweet }.to_json)

        id = response["data"]["id"] if response && response["data"] && response["data"]["id"]
        "https://x.com/#{username}/status/#{id}" if username && id
      rescue => e
        Rails.logger.error "Failed to post article #{article.id} to X: #{e.message}"
        nil
      end
    end

    private

    def create_client
      X::Client.new(
        api_key: @api_key,
        api_key_secret: @api_key_secret,
        access_token: @access_token,
        access_token_secret: @access_token_secret
      )
    end

    def build_tweet(article)
      post_url = "\nRead more:#{build_post_url(article.slug)}"
      max_length = 280 - 34 # URL固定23个字符+11个"\nRead more:"字符

      title = article.title
      content_text = article.description.presence || article.content.body.to_plain_text

      if title.length >= max_length - 3 # 减3是为了预留"..."的空间
        # 标题过长时，只显示标题（截断）和URL
        "#{title[0...(max_length - 3)]}...#{post_url}"
      else
        # 标题未超长时，计算剩余空间给正文内容
        remaining_length = max_length - title.length - 1 # 减1是为了标题后的换行符
        content_part = if remaining_length > 4 # 确保至少有空间放"..."
          "\n#{content_text[0...(remaining_length - 3)]}..."
        else
          ""
        end

        "#{title}#{content_part}#{post_url}"
      end
    end


    def build_post_url(article_slug)
      Rails.application.routes.url_helpers.article_url(
        article_slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end
  end
end
