class GithubBackupJob < ApplicationJob
  queue_as :default

  def perform
    service = GithubBackupService.new
    success = service.backup

    if success
      # Update last backup timestamp
      setting = Setting.first
      setting&.update(last_backup_at: Time.current)

      # Create ActivityLog record
      ActivityLog.create!(
        action: "completed",
        target: "github_backup",
        level: "info",
        description: "GitHub Backup completed successfully"
      )

      Rails.logger.info "GitHub backup completed successfully"
    else
      # Create ActivityLog record for failure
      ActivityLog.create!(
        action: "failed",
        target: "github_backup",
        level: "error",
        description: "GitHub Backup failed: #{service.error_message}"
      )

      Rails.logger.error "GitHub backup failed: #{service.error_message}"
    end
  end
end
