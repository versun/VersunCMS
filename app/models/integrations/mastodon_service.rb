module Integrations
  class MastodonService
    def initialize(article)
      @article = article
      @settings = Crosspost.mastodon
    end

    def verify(settings)
      if settings[:access_token].blank?
        return { success: false, error: "Access token are required" }
      end

      begin
        base_url =  "https://mastodon.social" if settings[:server_url].blank?
        client = Mastodon::REST::Client.new(
          base_url: base_url,
          bearer_token: settings[:access_token]
        )
        client.verify_credentials
        { success: true }
      rescue => e
        { success: false, error: "Mastodon verification failed: #{e.message}" }
      end
    end


    def post(article)
      return unless @settings&.enabled?

      require "mastodon"
      client = create_client
      status = build_status

      begin
        response = client.create_status(status)
        Rails.logger.info "Successfully posted article #{@article.id} to Mastodon"
        response.url
      rescue => e
        Rails.logger.error "Failed to post article #{@article.id} to Mastodon: #{e.message}"
        nil
      end
    end

    private

    def create_client
      Mastodon::REST::Client.new(
        base_url: @settings.server_url,
        bearer_token: @settings.access_token
      )
    end

    def build_status
      post_url = build_post_url
      content_text = @article.description.presence || @article.content.body.to_plain_text
      max_content_length = 500 - post_url.length - 30 - @article.title.length

      "#{@article.title}\n#{content_text[0...max_content_length]}...\nRead more: #{post_url}"
    end

    def build_post_url
      Rails.application.routes.url_helpers.article_url(
        @article.slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end
  end
end
