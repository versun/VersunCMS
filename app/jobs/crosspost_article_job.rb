class CrosspostArticleJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: ->(executions) { 2 ** executions }, attempts: 5

  def perform(article_id, platform)
    article = Article.find_by(id: article_id)
    return unless article

    social_media_posts = {}

    case platform
    when "mastodon"
        mastodon_url = MastodonService.new.post(article)
        if mastodon_url
          social_media_posts["mastodon"] = mastodon_url
        end
    when "twitter"
        twitter_url = TwitterService.new.post(article)
        if twitter_url
          social_media_posts["twitter"] = twitter_url
        end
    when "bluesky"
        bluesky_url = BlueskyService.new.post(article)
        if bluesky_url
          social_media_posts["bluesky"] = bluesky_url
        end
    end

    # Update article with all crosspost URLs at once
    social_media_posts.each do |platform, url|
      article.social_media_posts.find_or_initialize_by(platform: platform).update!(url: url)
    end

    # Log successful crosspost
    if social_media_posts.any?
      ActivityLog.create!(
        action: "completed",
        target: "crosspost",
        level: :info,
        description: "跨平台发布成功: #{article.title} (#{social_media_posts.keys.join(', ')})"
      )
    end

  rescue => e
    ActivityLog.create!(
      action: "failed",
      target: "crosspost",
      level: :error,
      description: "跨平台发布失败: #{article.title} (#{platform}) - #{e.message}"
    )
    raise
  end
end
