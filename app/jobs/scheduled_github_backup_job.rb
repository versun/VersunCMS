class ScheduledGithubBackupJob < ApplicationJob
  queue_as :default

  def perform
    setting = Setting.first

    # Check if scheduled backup is enabled and configured
    return unless setting&.github_backup_enabled
    return unless setting.github_backup_cron.present?
    return unless setting.github_repo_url.present?
    return unless setting.github_token.present?

    Rails.logger.info "Running scheduled GitHub backup (cron: #{setting.github_backup_cron})"

    # Trigger the backup job
    GithubBackupJob.perform_later
  end

  # Class method to register/update the scheduled job based on cron setting
  def self.update_schedule
    setting = Setting.first
    return unless setting

    # Remove existing scheduled job if any
    remove_schedule

    # Add new scheduled job if enabled, cron is set, and configuration is complete
    if setting.github_backup_enabled &&
       setting.github_backup_cron.present? &&
       setting.github_repo_url.present? &&
       setting.github_token.present?
      begin
        # Validate cron format using Fugit (used by SolidQueue)
        cron_schedule = setting.github_backup_cron.strip
        fugit_cron = Fugit.parse(cron_schedule)

        unless fugit_cron
          Rails.logger.error "Invalid cron format for GitHub backup: #{cron_schedule}"
          return
        end

        # Use SolidQueue::RecurringTask to create a dynamic (non-static) recurring task
        # This allows us to programmatically manage the schedule without editing recurring.yml
        Rails.logger.info "Scheduling GitHub backup with cron: #{cron_schedule}"

        SolidQueue::RecurringTask.find_or_initialize_by(key: "github_backup").tap do |task|
          task.class_name = "ScheduledGithubBackupJob"
          task.schedule = cron_schedule
          task.queue_name = "default"
          task.priority = 0
          task.static = false  # Mark as non-static so it can be managed programmatically
          task.description = "GitHub Backup scheduled task"
          task.save!
        end

        Rails.logger.info "GitHub backup scheduled successfully with cron: #{cron_schedule}"
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
