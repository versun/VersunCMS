class ScheduledGithubBackupJob < ApplicationJob
  queue_as :default

  def perform
    setting = Setting.first

    # Check if scheduled backup is enabled and configured
    return unless setting&.github_backup_enabled
    return unless setting.github_backup_schedule.present?
    return unless setting.github_repo_url.present?
    return unless setting.github_token.present?

    Rails.logger.info "Running scheduled GitHub backup (schedule: #{setting.github_backup_schedule})"

    # Trigger the backup job
    GithubBackupJob.perform_later
  end

  # Class method to register/update the scheduled job based on schedule setting
  def self.update_schedule
    setting = Setting.first
    return unless setting

    # Remove existing scheduled job if any
    remove_schedule

    # Add new scheduled job if enabled, schedule is set, and configuration is complete
    if setting.github_backup_enabled &&
       setting.github_backup_schedule.present? &&
       setting.github_repo_url.present? &&
       setting.github_token.present?
      begin
        # Convert schedule option to Solid Queue natural language syntax
        schedule_string = case setting.github_backup_schedule
        when 'daily'
          'every day at midnight'  # Daily at midnight
        when 'weekly'
          'every Monday at midnight'  # Weekly on Monday at midnight
        when 'monthly'
          'every month on the 1st at midnight'  # Monthly on 1st at midnight
        else
          Rails.logger.error "Invalid schedule option for GitHub backup: #{setting.github_backup_schedule}"
          return
        end

        # Validate schedule format using Fugit (used by SolidQueue)
        fugit_schedule = Fugit.parse(schedule_string)

        unless fugit_schedule
          Rails.logger.error "Invalid schedule format for GitHub backup: #{schedule_string}"
          return
        end

        # Use SolidQueue::RecurringTask to create a dynamic (non-static) recurring task
        # This allows us to programmatically manage the schedule without editing recurring.yml
        Rails.logger.info "Scheduling GitHub backup with schedule: #{setting.github_backup_schedule} (#{schedule_string})"

        SolidQueue::RecurringTask.find_or_initialize_by(key: "github_backup").tap do |task|
          task.class_name = "ScheduledGithubBackupJob"
          task.schedule = schedule_string
          task.queue_name = "default"
          task.priority = 0
          task.static = false  # Mark as non-static so it can be managed programmatically
          task.description = "GitHub Backup scheduled task (#{setting.github_backup_schedule})"
          task.save!
        end

        Rails.logger.info "GitHub backup scheduled successfully with schedule: #{setting.github_backup_schedule} (#{schedule_string})"
      rescue => e
        Rails.logger.error "Failed to schedule GitHub backup: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    else
      Rails.logger.info "GitHub backup schedule not created: configuration incomplete or disabled"
    end
  end

  def self.remove_schedule
    # Remove the dynamic recurring task if it exists
    task = SolidQueue::RecurringTask.find_by(key: "github_backup", static: false)
    if task
      task.destroy
      Rails.logger.info "Removed GitHub backup scheduled task"
    end
  rescue => e
    Rails.logger.error "Failed to remove GitHub backup schedule: #{e.message}"
  end
end
