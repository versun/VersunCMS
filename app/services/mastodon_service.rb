class MastodonService
  def initialize(article)
    @article = article
    @settings = CrosspostSetting.mastodon
  end

  def verify(settings)
    return false if settings.server_url.blank? || settings.access_token.blank?

    client = Mastodon::REST::Client.new(
      base_url: settings.server_url,
      bearer_token: settings.access_token
    )
    client.verify_credentials
    true
  rescue => e
    Rails.logger.error "Mastodon verification failed: #{e.message}"
    false
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
    content_text = @article.description || @article.content.body.to_plain_text
    max_content_length = 500 - post_url.length - 30
    
    "#{@article.title}\n#{content_text[0...max_content_length]}\n...\n\nRead more: #{post_url}"
  end

  def build_post_url
    Rails.application.routes.url_helpers.article_url(
      @article.slug,
      host: Setting.first.url.sub(%r{https?://}, "")
    )
  end
end