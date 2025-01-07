class BackupJob < ApplicationJob
  queue_as :default

  def perform
    settings = BackupSetting.instance
    return unless settings && settings.s3_enabled

    ActivityLog.create!(action: "backup", target: "backup", level: :info, description: "Starting backup...")

    begin
      # Create zip backup
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      backup_zip = settings.create_zip_backup(timestamp)

      if backup_zip
        # Upload to S3
        settings.upload_to_s3(backup_zip, timestamp)
        settings.cleanup_old_backups

        settings.update(last_backup_at: Time.current)
        ActivityLog.create!(
          action: "backup",
          target: "backup",
          level: :info,
          description: "Backup completed successfully: #{File.basename(backup_zip)}"
        )
      end
    rescue Aws::S3::Errors::ServiceError => e
      ActivityLog.create!(
        action: "backup",
        target: "backup",
        level: :error,
        description: "S3 upload failed: #{e.message}"
      )
      raise e
    rescue StandardError => e
      ActivityLog.create!(
        action: "backup",
        target: "backup",
        level: :error,
        description: "Backup failed: #{e.message}"
      )
      raise e
    ensure
      settings.cleanup_temp_files
    end
  end
end
