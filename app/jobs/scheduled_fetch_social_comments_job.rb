class ScheduledFetchSocialCommentsJob < ApplicationJob
  queue_as :default

  def perform
    # Check if any platform has scheduled comment fetching enabled
    enabled_platforms = Crosspost.where(enabled: true)
                                 .where.not(comment_fetch_schedule: [ nil, "" ])
                                 .where(auto_fetch_comments: true)

    return if enabled_platforms.empty?

    Rails.event.notify "scheduled_fetch_social_comments_job.started",
      level: "info",
      component: "ScheduledFetchSocialCommentsJob",
      platforms_count: enabled_platforms.count

    # Trigger the fetch job
    FetchSocialCommentsJob.perform_later
  end

  # Class method to register/update the scheduled job based on crosspost settings
  def self.update_schedule
    # Check if any crosspost has comment fetching enabled with a schedule
    enabled_platforms = Crosspost.where(enabled: true)
                                 .where.not(comment_fetch_schedule: [ nil, "" ])
                                 .where(auto_fetch_comments: true)

    # Remove existing scheduled job if any
    remove_schedule

    # Add new scheduled job if any platform is configured
    if enabled_platforms.any?
      begin
        # Use the first enabled platform's schedule (all should be the same ideally)
        # In practice, we'll use a common schedule for all platforms
        first_platform = enabled_platforms.first
        schedule_option = first_platform.comment_fetch_schedule

        # Convert schedule option to Solid Queue natural language syntax
        schedule_string = case schedule_option
        when "daily"
          "every day at midnight"  # Daily at midnight
        when "weekly"
          "every Monday at midnight"  # Weekly on Monday at midnight
        when "monthly"
          "every month on the 1st at midnight"  # Monthly on 1st at midnight
        else
          Rails.event.notify "scheduled_fetch_social_comments_job.invalid_schedule",
            level: "error",
            component: "ScheduledFetchSocialCommentsJob",
            schedule_option: schedule_option
          return
        end

        # Validate schedule format using Fugit (used by SolidQueue)
        fugit_schedule = Fugit.parse(schedule_string)

        unless fugit_schedule
          Rails.event.notify "scheduled_fetch_social_comments_job.invalid_schedule_format",
            level: "error",
            component: "ScheduledFetchSocialCommentsJob",
            schedule_string: schedule_string
          return
        end

        # Use SolidQueue::RecurringTask to create a dynamic (non-static) recurring task
        Rails.event.notify "scheduled_fetch_social_comments_job.scheduling",
          level: "info",
          component: "ScheduledFetchSocialCommentsJob",
          schedule_option: schedule_option,
          schedule_string: schedule_string

        SolidQueue::RecurringTask.find_or_initialize_by(key: "fetch_social_comments").tap do |task|
          task.class_name = "ScheduledFetchSocialCommentsJob"
          task.schedule = schedule_string
          task.queue_name = "default"
          task.priority = 0
          task.static = false  # Mark as non-static so it can be managed programmatically
          task.description = "Social Comments Fetch scheduled task (#{schedule_option})"
          task.save!
        end

        Rails.event.notify "scheduled_fetch_social_comments_job.scheduled",
          level: "info",
          component: "ScheduledFetchSocialCommentsJob",
          schedule_option: schedule_option,
          schedule_string: schedule_string
      rescue => e
        Rails.event.notify "scheduled_fetch_social_comments_job.schedule_failed",
          level: "error",
          component: "ScheduledFetchSocialCommentsJob",
          error_message: e.message
        Rails.event.notify "scheduled_fetch_social_comments_job.error_backtrace",
          level: "error",
          component: "ScheduledFetchSocialCommentsJob",
          backtrace: e.backtrace.join("\n")
      end
    else
      Rails.event.notify "scheduled_fetch_social_comments_job.no_platforms",
        level: "info",
        component: "ScheduledFetchSocialCommentsJob"
    end
  end

  def self.remove_schedule
    # Remove the dynamic recurring task if it exists
    task = SolidQueue::RecurringTask.find_by(key: "fetch_social_comments", static: false)
    if task
      task.destroy
      Rails.event.notify "scheduled_fetch_social_comments_job.schedule_removed",
        level: "info",
        component: "ScheduledFetchSocialCommentsJob"
    end
  rescue => e
    Rails.event.notify "scheduled_fetch_social_comments_job.remove_failed",
      level: "error",
      component: "ScheduledFetchSocialCommentsJob",
      error_message: e.message
  end
end
