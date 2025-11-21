class FetchSocialCommentsJob < ApplicationJob
  queue_as :default

  def perform
    fetch_mastodon_comments if mastodon_enabled?
    fetch_bluesky_comments if bluesky_enabled?
  end

  private

  def mastodon_enabled?
    mastodon_settings = Crosspost.find_by(platform: "mastodon")
    mastodon_settings&.enabled? && mastodon_settings&.auto_fetch_comments
  end

  def bluesky_enabled?
    bluesky_settings = Crosspost.find_by(platform: "bluesky")
    bluesky_settings&.enabled? && bluesky_settings&.auto_fetch_comments
  end

  def fetch_mastodon_comments
    Rails.logger.info "Starting Mastodon comment fetch"

    articles = Article.published
                      .joins(:social_media_posts)
                      .where(social_media_posts: { platform: "mastodon" })
                      .where.not(social_media_posts: { url: nil })
                      .distinct

    process_platform_comments(articles, "mastodon", Integrations::MastodonService.new, rate_limit_thresholds: { stop: 5, delay: 20 })
  end

  def fetch_bluesky_comments
    Rails.logger.info "Starting Bluesky comment fetch"

    articles = Article.published
                      .joins(:social_media_posts)
                      .where(social_media_posts: { platform: "bluesky" })
                      .where.not(social_media_posts: { url: nil })
                      .distinct

    process_platform_comments(articles, "bluesky", Integrations::BlueskyService.new, rate_limit_thresholds: { stop: 50, delay: 200 })
  end

  def process_platform_comments(articles, platform, service, rate_limit_thresholds:)
    success_count = 0
    error_count = 0
    total_comments = 0
    stopped_due_to_rate_limit = false

    articles.each do |article|
      begin
        post = article.social_media_posts.find_by(platform: platform)
        next unless post&.url

        # Fetch comments from platform
        result = service.fetch_comments(post.url)

        # Handle rate limit info
        if result[:rate_limit]
          rate_limit = result[:rate_limit]

          # Stop processing if rate limit is critically low
          if rate_limit[:remaining] && rate_limit[:remaining] < rate_limit_thresholds[:stop]
            Rails.logger.warn "⚠️  Stopping #{platform} comment fetch: Rate limit too low (#{rate_limit[:remaining]} remaining)"
            ActivityLog.create!(
              action: "paused",
              target: "fetch_comments",
              level: :warning,
              description: "Paused #{platform.capitalize} comment fetching due to low rate limit: #{rate_limit[:remaining]}/#{rate_limit[:limit]} remaining. Will resume after #{rate_limit[:reset_at]}"
            )
            stopped_due_to_rate_limit = true
            break
          end

          # Add delay if rate limit is getting low
          if rate_limit[:remaining] && rate_limit[:remaining] < rate_limit_thresholds[:delay]
            sleep_time = 2
            Rails.logger.info "#{platform.capitalize} rate limit low (#{rate_limit[:remaining]}), adding #{sleep_time}s delay"
            sleep(sleep_time)
          end
        end

        comments_data = result[:comments]

        # Create or update comments with deduplication
        comments_data.each do |comment_data|
          comment = article.comments.find_or_initialize_by(
            platform: platform,
            external_id: comment_data[:external_id]
          )

          comment.assign_attributes(
            author_name: comment_data[:author_name],
            author_username: comment_data[:author_username],
            author_avatar_url: comment_data[:author_avatar_url],
            content: comment_data[:content],
            published_at: comment_data[:published_at],
            url: comment_data[:url]
          )

          if comment.new_record?
            comment.save!
            total_comments += 1
            Rails.logger.info "Created new #{platform} comment for article #{article.slug}"
          elsif comment.changed?
            comment.save!
            Rails.logger.info "Updated #{platform} comment for article #{article.slug}"
          end
        end

        success_count += 1
      rescue => e
        error_count += 1
        Rails.logger.error "Failed to fetch #{platform} comments for article #{article.slug}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        ActivityLog.create!(
          action: "failed",
          target: "fetch_comments",
          level: :error,
          description: "Failed to fetch #{platform.capitalize} comments for article #{article.slug}: #{e.message}"
        )
      end
    end

    # Log summary
    summary_message = "Fetched #{platform.capitalize} comments: #{success_count} articles processed, #{total_comments} new comments, #{error_count} errors"
    summary_message += " (stopped early due to rate limit)" if stopped_due_to_rate_limit

    ActivityLog.create!(
      action: "completed",
      target: "fetch_comments",
      level: :info,
      description: summary_message
    )

    Rails.logger.info "Completed #{platform.capitalize} comment fetch: #{success_count} success, #{error_count} errors, #{total_comments} new comments"
  end
end
