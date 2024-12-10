# COPY from: https://t27duck.com/posts/17-a-bluesky-at-proto-api-example-in-ruby
class BlueskyService
  TOKEN_CACHE_KEY = :bluesky_token_data
  
  def initialize(article)
    @article = article
    @settings = CrosspostSetting.bluesky
    @username = @settings.access_token
    @password = @settings.access_token_secret
    @server_url = @settings.server_url
    token_data = Rails.cache.read(TOKEN_CACHE_KEY)
    process_tokens(token_data) if token_data.present?
  end

  def self.verify(settings)
    return false if settings.access_token.blank? || settings.access_token_secret.blank?
    client = Minisky::Client.new(
      identifier: settings.access_token,
      password: settings.access_token_secret,
      host: settings.server_url || "https://bsky.app"
    )

    client.get_profile
    true
  rescue => e
    Rails.logger.error "Bluesky verification failed: #{e.message}"
    false
  end
  
  def post(article)
    return unless @settings&.enabled?

    client = create_client
    content = build_content
    
    begin
      response = client.create_post(text: content)
      post_url = build_post_url(response)
      Rails.logger.info "Successfully posted article #{@article.id} to Bluesky"
      post_url
    rescue => e
      Rails.logger.error "Failed to post article #{@article.id} to Bluesky: #{e.message}"
      nil
    end
  end

  private

  def create_client
    AtProto::Client.new(
      identifier: @settings.access_token,
      password: @settings.access_token_secret,
      host: @settings.server_url || "https://bsky.social"
    )
  end

  def build_content
    post_url = build_post_url
    content_text = @article.description || @article.content.body.to_plain_text
    max_content_length = 300 - post_url.length - 30
    
    "#{@article.title}\n#{content_text[0...max_content_length]}\n...\n\nRead more: #{post_url}"
  end

  def build_post_url(response = nil)
    if response&.uri
      "https://bsky.app/profile/#{@settings.access_token}/post/#{response.uri.split('/').last}"
    else
      Rails.application.routes.url_helpers.article_url(
        @article.slug,
        host: Setting.first.url.sub(%r{https?://}, "")
      )
    end
  end
end