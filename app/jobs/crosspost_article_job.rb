class CrosspostArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    if article.crosspost_mastodon?
      post_to_mastodon(article)
    end

    if article.crosspost_twitter?
      post_to_twitter(article)
    end
  end

  private

  def post_to_mastodon(article)
    settings = CrosspostSetting.mastodon
    return unless settings&.enabled?

    require 'mastodon'
    
    client = Mastodon::REST::Client.new(
      base_url: settings.server_url,
      bearer_token: settings.access_token
    )

    post_url = Rails.application.routes.url_helpers.article_url(
      article.slug, 
      host: Setting.first.url.sub(%r{https?://}, '')
    )
    # Extract text content from rich text
    content_text = article.content.body.to_plain_text

    # Create status with title, content and URL
    # Mastodon has a 500 character limit, so we'll truncate if needed
    max_content_length = 500 - post_url.length - 30
    status = "#{article.title}\n\n#{content_text[0...max_content_length]}\n..."
    status += "\n\nRead more: #{post_url}"

    begin
      client.create_status(status)
      Rails.logger.info "Successfully posted article #{article.id} to Mastodon"
    rescue => e
      Rails.logger.error "Failed to post article #{article.id} to Mastodon: #{e.message}"
    end
  end

  def post_to_twitter(article)
    settings = CrosspostSetting.twitter
    return unless settings&.enabled?

    require 'x'
    
    client = X::Client.new(
      api_key: settings.client_id,
      api_key_secret: settings.client_secret,
      access_token: settings.access_token,
      access_token_secret: settings.settings['access_token_secret']
    )

    post_url = Rails.application.routes.url_helpers.article_url(
      article.slug, 
      host: Setting.first.url.sub(%r{https?://}, '')
    )
    status = "#{article.title}\n\n#{post_url}"

    begin
      client.post(text: status)
      Rails.logger.info "Successfully posted article #{article.id} to X"
    rescue => e
      Rails.logger.error "Failed to post article #{article.id} to X: #{e.message}"
    end
  end
end
