class ScheduledFetchSocialCommentsJob < ApplicationJob
  queue_as :default

  def perform
    # Check if any platform has scheduled comment fetching enabled
    enabled_platforms = Crosspost.where(enabled: true)
                                 .where.not(comment_fetch_schedule: [nil, ''])
                                 .where(auto_fetch_comments: true)

    return if enabled_platforms.empty?

    Rails.logger.info "Running scheduled social comments fetch for #{enabled_platforms.count} platform(s)"

    # Trigger the fetch job
    FetchSocialCommentsJob.perform_later
  end

  # Class method to register/update the scheduled job based on crosspost settings
  def self.update_schedule
    # Check if any crosspost has comment fetching enabled with a schedule
    enabled_platforms = Crosspost.where(enabled: true)
                                 .where.not(comment_fetch_schedule: [nil, ''])
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
        when 'daily'
          'every day at midnight'  # Daily at midnight
        when 'weekly'
          'every Monday at midnight'  # Weekly on Monday at midnight
        when 'monthly'
          'every month on the 1st at midnight'  # Monthly on 1st at midnight
        else
          Rails.logger.error "Invalid schedule option for comment fetch: #{schedule_option}"
          return
        end

        # Validate schedule format using Fugit (used by SolidQueue)
        fugit_schedule = Fugit.parse(schedule_string)

        unless fugit_schedule
          Rails.logger.error "Invalid schedule format for comment fetch: #{schedule_string}"
          return
        end

        # Use SolidQueue::RecurringTask to create a dynamic (non-static) recurring task
        Rails.logger.info "Scheduling comment fetch with schedule: #{schedule_option} (#{schedule_string})"

        SolidQueue::RecurringTask.find_or_initialize_by(key: "fetch_social_comments").tap do |task|
          task.class_name = "ScheduledFetchSocialCommentsJob"
          task.schedule = schedule_string
          task.queue_name = "default"
          task.priority = 0
          task.static = false  # Mark as non-static so it can be managed programmatically
          task.description = "Social Comments Fetch scheduled task (#{schedule_option})"
          task.save!
        end

        Rails.logger.info "Comment fetch scheduled successfully with schedule: #{schedule_option} (#{schedule_string})"
      rescue => e
        Rails.logger.error "Failed to schedule comment fetch: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    else
      Rails.logger.info "Comment fetch schedule not created: no platforms configured"
    end
  end

  def self.remove_schedule
    # Remove the dynamic recurring task if it exists
    task = SolidQueue::RecurringTask.find_by(key: "fetch_social_comments", static: false)
    if task
      task.destroy
      Rails.logger.info "Removed comment fetch scheduled task"
    end
  rescue => e
    Rails.logger.error "Failed to remove comment fetch schedule: #{e.message}"
  end
end


