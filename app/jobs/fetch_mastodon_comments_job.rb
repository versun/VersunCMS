class FetchMastodonCommentsJob < ApplicationJob
  queue_as :default

  def perform
    # Check if Mastodon crosspost is enabled and auto-fetch is enabled
    mastodon_settings = Crosspost.find_by(platform: 'mastodon')
    return unless mastodon_settings&.enabled? && mastodon_settings&.auto_fetch_comments

    Rails.logger.info "Starting Mastodon comment fetch job"
    
    # Find all published articles with Mastodon posts
    articles_with_mastodon = Article.published
                                    .joins(:social_media_posts)
                                    .where(social_media_posts: { platform: 'mastodon' })
                                    .where.not(social_media_posts: { url: nil })
                                    .distinct

    success_count = 0
    error_count = 0
    total_comments = 0
    stopped_due_to_rate_limit = false

    articles_with_mastodon.each do |article|
      begin
        mastodon_post = article.social_media_posts.find_by(platform: 'mastodon')
        next unless mastodon_post&.url

        # Fetch comments from Mastodon
        service = Integrations::MastodonService.new
        result = service.fetch_comments(mastodon_post.url)
        
        # Handle rate limit info
        if result[:rate_limit]
          rate_limit = result[:rate_limit]
          
          # Stop processing if rate limit is critically low
          if rate_limit[:remaining] && rate_limit[:remaining] < 5
            Rails.logger.warn "⚠️  Stopping comment fetch: Rate limit too low (#{rate_limit[:remaining]} remaining)"
            ActivityLog.create!(
              action: "paused",
              target: "fetch_comments",
              level: :warning,
              description: "Paused Mastodon comment fetching due to low rate limit: #{rate_limit[:remaining]}/#{rate_limit[:limit]} remaining. Will resume after #{rate_limit[:reset_at]}"
            )
            stopped_due_to_rate_limit = true
            break
          end
          
          # Add delay if rate limit is getting low
          if rate_limit[:remaining] && rate_limit[:remaining] < 20
            sleep_time = 2 # 2 seconds delay
            Rails.logger.info "Rate limit low (#{rate_limit[:remaining]}), adding #{sleep_time}s delay"
            sleep(sleep_time)
          end
        end

        comments_data = result[:comments]

        # Create or update comments with deduplication
        comments_data.each do |comment_data|
          comment = article.comments.find_or_initialize_by(
            platform: 'mastodon',
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
            Rails.logger.info "Created new comment for article #{article.slug}"
          elsif comment.changed?
            comment.save!
            Rails.logger.info "Updated comment for article #{article.slug}"
          end
        end

        success_count += 1
      rescue => e
        error_count += 1
        Rails.logger.error "Failed to fetch comments for article #{article.slug}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        ActivityLog.create!(
          action: "failed",
          target: "fetch_comments",
          level: :error,
          description: "Failed to fetch Mastodon comments for article #{article.slug}: #{e.message}"
        )
      end
    end

    # Log summary
    summary_message = "Fetched Mastodon comments: #{success_count} articles processed, #{total_comments} new comments, #{error_count} errors"
    summary_message += " (stopped early due to rate limit)" if stopped_due_to_rate_limit
    
    ActivityLog.create!(
      action: "completed",
      target: "fetch_comments",
      level: :info,
      description: summary_message
    )

    Rails.logger.info "Completed Mastodon comment fetch: #{success_count} success, #{error_count} errors, #{total_comments} new comments"
  end
end
