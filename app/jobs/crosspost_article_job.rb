class CrosspostArticleJob < ApplicationJob
  queue_as :default

  # 重试机制：对于 Internet Archive 的速率限制错误，使用指数退避重试
  retry_on StandardError, wait: :exponentially_longer, attempts: 5 do |job, error|
    # 对于 Internet Archive 的速率限制，使用更长的等待时间
    if job.arguments[1] == "internet_archive" && error.message.include?("rate limit")
      Rails.logger.warn "Internet Archive rate limit hit, will retry with exponential backoff"
    end
  end

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
    when "internet_archive"
        archive_url = Integrations::InternetArchiveService.new.post(article)
        if archive_url
          social_media_posts["internet_archive"] = archive_url
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

    # Schedule static page regeneration after successful crosspost (2 min delay)
    # Only if auto-regenerate is enabled for crosspost updates
    if social_media_posts.any? && Setting.first_or_create.auto_regenerate_enabled?("crosspost_update")
      GenerateStaticFilesJob.schedule_debounced(
        type: "article",
        id: article_id,
        delay: 2.minutes
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
