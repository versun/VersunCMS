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

    # Add new scheduled job if enabled and cron is set
    if setting.github_backup_enabled && setting.github_backup_cron.present?
      begin
        # Parse cron expression and schedule the job
        # Using solid_queue's recurring task functionality
        Rails.logger.info "Scheduling GitHub backup with cron: #{setting.github_backup_cron}"
        
        # Note: For solid_queue, you would typically define recurring jobs in config/recurring.yml
        # This method is a placeholder for future integration
        # For now, users need to manually add to config/recurring.yml:
        #
        # scheduled_github_backup:
        #   class: ScheduledGithubBackupJob
        #   schedule: "0 2 * * *"  # User's cron expression
        
      rescue => e
        Rails.logger.error "Failed to schedule GitHub backup: #{e.message}"
      end
    end
  end

  def self.remove_schedule
    # Placeholder for removing scheduled job
    # In solid_queue, you would modify config/recurring.yml
    Rails.logger.info "Note: To enable/disable scheduled backups, update config/recurring.yml"
  end
end
