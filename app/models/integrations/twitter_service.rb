require "x"
module Integrations
  class TwitterService
    def initialize(article)
      @article = article
      @settings = Crosspost.twitter
    end

    def verify(settings)
      if settings[:client_id].blank? || settings[:client_secret].blank? || settings[:access_token].blank?
        return { success: false, error: "Client ID, client secret, and access token are required" }
      end

      begin
          client = X::Client.new(
            api_key: settings[:client_id],
            api_key_secret: settings[:client_secret],
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
      tweet = build_tweet

      begin
        user = client.get("users/me")
        username = user["data"]["username"] if user && user["data"]
        response = client.post("tweets", { text: tweet }.to_json)

        id = response["data"]["id"] if response && response["data"] && response["data"]["id"]
        "https://x.com/#{username}/status/#{id}" if username && id
      rescue => e
        Rails.logger.error "Failed to post article #{@article.id} to X: #{e.message}"
        nil
      end
    end

    private

    def create_client
      X::Client.new(
        api_key: @settings.client_id,
        api_key_secret: @settings.client_secret,
        access_token: @settings.access_token,
        access_token_secret: @settings.access_token_secret
      )
    end

    def build_tweet
      post_url = "\nRead more:#{build_post_url}"
      max_length = 140 - post_url.length # 预留URL和"Read more:"的空间

      title = @article.title
      content_text = @article.description.presence || @article.content.body.to_plain_text

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


    def build_post_url
      Rails.application.routes.url_helpers.article_url(
        @article.slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end
  end
end
