class CrosspostArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    social_media_posts = {}

    if article.crosspost_mastodon?
      if mastodon_url = Integrations::MastodonService.new(article).post(article)
        social_media_posts["mastodon"] = mastodon_url
      end
    end

    if article.crosspost_twitter?
      if twitter_url = Integrations::TwitterService.new(article).post(article)
        social_media_posts["twitter"] = twitter_url
      end
    end

    if article.crosspost_bluesky?
      if bluesky_url = Integrations::BlueskyService.new(article).post(article)
        social_media_posts["bluesky"] = bluesky_url
      end
    end

    # Update article with all crosspost URLs at once
    social_media_posts.each do |platform, url|
      article.social_media_posts.find_or_initialize_by(platform: platform).update!(url: url)
    end
  end
end
