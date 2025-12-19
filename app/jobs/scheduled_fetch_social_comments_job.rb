# Scheduled job that runs hourly (via config/recurring.yml) and checks
# if it's time to fetch social comments based on crosspost settings.
#
# This approach ensures the job persists after service restart since it's
# defined as a static recurring task, not dynamically created.
class ScheduledFetchSocialCommentsJob < ApplicationJob
  queue_as :default

  CACHE_KEY = "social_comments_last_fetch_at".freeze

  def perform
    enabled_platforms = Crosspost.where(enabled: true)
                                 .where(auto_fetch_comments: true)
                                 .where.not(comment_fetch_schedule: [ nil, "" ])

    if enabled_platforms.empty?
      Rails.event.notify "scheduled_fetch_social_comments_job.skipped",
        level: "debug",
        component: "ScheduledFetchSocialCommentsJob",
        reason: "no_enabled_platforms"
      return
    end

    # Use the first platform's schedule (all should typically be the same)
    schedule = enabled_platforms.first.comment_fetch_schedule
    last_fetch_at = Rails.cache.read(CACHE_KEY)

    unless should_fetch_now?(schedule, last_fetch_at)
      Rails.event.notify "scheduled_fetch_social_comments_job.skipped",
        level: "debug",
        component: "ScheduledFetchSocialCommentsJob",
        reason: "not_time_yet",
        schedule: schedule,
        last_fetch_at: last_fetch_at&.iso8601
      return
    end

    # Update last fetch time before triggering to avoid duplicate runs
    Rails.cache.write(CACHE_KEY, Time.current, expires_in: 2.months)

    Rails.event.notify "scheduled_fetch_social_comments_job.triggering",
      level: "info",
      component: "ScheduledFetchSocialCommentsJob",
      schedule: schedule,
      platforms_count: enabled_platforms.count

    # Trigger the actual fetch job
    FetchSocialCommentsJob.perform_later
  end

  private

  def should_fetch_now?(schedule, last_fetch_at)
    # If never fetched before, fetch now
    return true if last_fetch_at.nil?

    case schedule
    when "daily"
      last_fetch_at < 1.day.ago
    when "weekly"
      last_fetch_at < 1.week.ago
    when "monthly"
      last_fetch_at < 1.month.ago
    else
      Rails.event.notify "scheduled_fetch_social_comments_job.unknown_schedule",
        level: "warn",
        component: "ScheduledFetchSocialCommentsJob",
        schedule: schedule
      false
    end
  end
end
