require "net/http"
require "uri"

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
      status_text = build_status
      uri = URI.join(@settings[:server_url], "/api/v1/statuses")

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          status: status_text,
          visibility: "public"
        )
        request["Authorization"] = "Bearer #{@settings.access_token}"

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          json_response = JSON.parse(response.body)
          Rails.logger.info "Successfully posted article #{@article.id} to Mastodon"
          json_response["url"]
        else
          Rails.logger.error "Failed to post article #{@article.id} to Mastodon: #{response.code} #{response.message}"
          nil
        end
      rescue => e
        Rails.logger.error "Failed to post article #{@article.id} to Mastodon: #{e.message}"
        nil
      end
    end

    private

    # def create_client
    #   Mastodon::REST::Client.new(
    #     base_url: @settings[:server_url],
    #     bearer_token: @settings.access_token
    #   )
    # end

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
