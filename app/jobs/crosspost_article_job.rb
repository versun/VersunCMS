class CrosspostArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    crosspost_urls = {}

    if article.crosspost_mastodon?
      if mastodon_url = Integrations::MastodonService.new(article).post(article)
        crosspost_urls["mastodon"] = mastodon_url
      end
    end

    if article.crosspost_twitter?
      if twitter_url = Integrations::TwitterService.new(article).post(article)
        crosspost_urls["twitter"] = twitter_url
      end
    end

    if article.crosspost_bluesky?
      if bluesky_url = Integrations::BlueskyService.new(article).post(article)
        crosspost_urls["bluesky"] = bluesky_url
      end
    end

    # Update article with all crosspost URLs at once
    article.update_column(:crosspost_urls, crosspost_urls) unless crosspost_urls.empty?
  end
end
