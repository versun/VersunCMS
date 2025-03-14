class CrosspostArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id, platform)
    article = Article.find_by(id: article_id)
    return unless article

    social_media_posts = {}

    case platform
    when "mastodon"
        mastodon_url = Integrations::MastodonService.new.post(article)
        if mastodon_url
          social_media_posts["mastodon"] = mastodon_url
        end
    when "twitter"
        twitter_url = Integrations::TwitterService.new.post(article)
        if twitter_url
          social_media_posts["twitter"] = twitter_url
        end
    when "bluesky"
        bluesky_url = Integrations::BlueskyService.new.post(article)
        if bluesky_url
          social_media_posts["bluesky"] = bluesky_url
        end
    end

    # Update article with all crosspost URLs at once
    social_media_posts.each do |platform, url|
      article.social_media_posts.find_or_initialize_by(platform: platform).update!(url: url)
    end
  end
end
