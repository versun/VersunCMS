class BackupJob < ApplicationJob
  queue_as :default
  require "aws-sdk-s3"
  require_relative "../models/tools/export"

  def perform
    settings = BackupSetting.instance
    return unless settings && settings.s3_enabled

    ActivityLog.create!(action: "backup", target: "backup", level: :info, description: "Starting backup...")

    begin
      # Create zip backup
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      backup_zip = create_zip_backup(timestamp)

      if backup_zip
        # Upload to S3
        upload_to_s3(backup_zip, timestamp, settings)
        cleanup_old_backups(settings)

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
      cleanup_temp_files
    end
  end

  private

  def create_zip_backup(timestamp)
    export = Tools::Export.new
    if export.generate
      zip_dir = Rails.root.join("storage", "backup", "temp")
      FileUtils.mkdir_p(zip_dir)
      backup_zip = File.join(zip_dir, "backup_#{timestamp}.zip")
      FileUtils.mv(export.zip_path, backup_zip)
      backup_zip
    else
      ActivityLog.create!(
        action: "backup",
        target: "backup",
        level: :error,
        description: "Zip export failed: #{export.error_message}"
      )
      nil
    end
  end

  def upload_to_s3(backup_zip, timestamp, settings)
    s3_client = settings.s3_client

    File.open(backup_zip, "rb") do |file|
      key = File.join(
        settings.s3_prefix,
        timestamp[0..3],  # Year
        timestamp[4..5],  # Month
        File.basename(backup_zip)
      )

      s3_client.put_object(
        bucket: settings.s3_bucket,
        key: key,
        body: file,
        content_type: "application/zip",
        metadata: {
          "backup-date" => Time.current.iso8601,
          "backup-type" => "full"
        }
      )

      ActivityLog.create!(
        action: "backup",
        target: "backup",
        level: :info,
        description: "Uploaded to S3: #{key}"
      )
    end
  end

  def cleanup_old_backups(settings)
    return unless settings.backup_retention_days.positive?

    s3_client = settings.s3_client

    retention_date = Time.current - settings.backup_retention_days.days

    s3_client.list_objects_v2(
      bucket: settings.s3_bucket,
      prefix: settings.s3_prefix
    ).each do |response|
      response.contents.each do |object|
        if object.last_modified < retention_date
          s3_client.delete_object(
            bucket: settings.s3_bucket,
            key: object.key
          )

          ActivityLog.create!(
            action: "backup",
            target: "backup",
            level: :info,
            description: "Deleted old backup: #{object.key}"
          )
        end
      end
    end
  end

  def cleanup_temp_files
    temp_dir = Rails.root.join("storage", "backup", "temp")
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end
end
