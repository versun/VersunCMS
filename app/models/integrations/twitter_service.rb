module Integrations
  class TwitterService
    def initialize(article)
      @article = article
      @settings = Crosspost.twitter
    end

    def verify(settings)
      return false if settings[:client_id].blank? || settings[:client_secret].blank? || settings[:access_token].blank?

      require "x"

      client = X::Client.new(
        api_key: settings[:client_id],
        api_key_secret: settings[:client_secret],
        access_token: settings[:access_token],
        access_token_secret: settings[:access_token_secret]
      )

      # Try to post a test tweet to verify credentials
      test_response = client.get("users/me")
      if test_response && test_response["data"] && test_response["data"]["id"]
        Rails.logger.info "Twitter credentials verified successfully! #{test_response}"
        true
      else
        Rails.logger.error "Twitter verification failed: #{test_response}"
      end

    rescue => e
      Rails.logger.error "Twitter verification failed: #{e.message}"
      false
    end

    def post(article)
      return unless @settings&.enabled?

      require "x"
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
      post_url = build_post_url
      content_text = @article.description || @article.content.body.to_plain_text
      max_content_length = 140 - post_url.length - 30

      "#{@article.title}\n#{content_text[0...max_content_length]}...\n\nRead more: #{post_url}"
    end

    def build_post_url
      Rails.application.routes.url_helpers.article_url(
        @article.slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end
  end
end
