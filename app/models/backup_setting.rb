class BackupSetting < ApplicationRecord
  # S3 configuration validations
  validates :s3_bucket, presence: true, if: :s3_enabled
  validates :s3_region, presence: true, if: :s3_enabled
  validates :s3_access_key_id, presence: true, if: :s3_enabled
  validates :s3_secret_access_key, presence: true, if: :s3_enabled

  # Backup schedule validations
  validates :backup_interval_hours,
            numericality: { greater_than: 0 },
            presence: true,
            if: :auto_backup
  validates :backup_retention_days,
            numericality: { greater_than: 0 },
            presence: true

  # Default values
  after_initialize :set_defaults, if: :new_record?

  def self.instance
    first_or_initialize
  end

  def recent_backup_logs(limit = 10)
    ActivityLog.where(target: "backup").order(created_at: :desc).limit(limit)
  end

  def last_backup_status
    last_backup = ActivityLog.where(target: "backup").last
    {
      last_backup: last_backup&.created_at,
      status: last_backup&.level,
      message: last_backup&.description
    }
  end

  def next_backup_due?
    return false unless auto_backup && last_backup_at.present?

    Time.current >= last_backup_at + backup_interval_hours.hours
  end

  def backup_due_in
    return 0 unless auto_backup && last_backup_at.present?

    next_backup = last_backup_at + backup_interval_hours.hours
    [ 0, (next_backup - Time.current) ].max
  end

  def s3_client
    return nil unless s3_enabled
    require "aws-sdk-s3"
    endpoint = if s3_endpoint.present?
                s3_endpoint.start_with?("http") ? s3_endpoint : "https://#{s3_endpoint}"
    else
                "https://s3.#{s3_region}.amazonaws.com"
    end

    Aws::S3::Client.new(
      region: s3_region,
      credentials: Aws::Credentials.new(s3_access_key_id, s3_secret_access_key),
      endpoint: endpoint
    )
  end

  def list_backups
    return [] unless s3_enabled && s3_client

    prefix = s3_prefix.present? ? "#{s3_prefix}/" : ""
    objects = s3_client.list_objects_v2(bucket: s3_bucket, prefix: prefix)
    objects.contents.map do |obj|
      {
        key: obj.key,
        size: obj.size,
        last_modified: obj.last_modified
      }
    end.sort_by { |backup| backup[:last_modified] }.reverse
  end

  def restore_backup(backup_key)
    return false unless s3_enabled && s3_client

    begin
      Rails.logger.info "Starting backup restore from key: #{backup_key}"

      # Download backup file
      temp_dir = Rails.root.join("storage", "backup", "temp")
      FileUtils.mkdir_p(temp_dir)
      temp_zip = File.join(temp_dir, "restore_backup.zip")

      Rails.logger.info "Downloading backup file to: #{temp_zip}"
      s3_client.get_object(
        bucket: s3_bucket,
        key: backup_key,
        response_target: temp_zip
      )

      # Use Tools::Import to restore
      importer = Tools::Import.new
      if importer.restore(temp_zip)
        ActivityLog.create!(
          action: "restore",
          target: "backup",
          level: :info,
          description: "Successfully restored all databases from #{backup_key}"
        )

        # Refresh all settings cache after restore
        SettingsService.refresh_all

        true
      else
        ActivityLog.create!(
          action: "restore",
          target: "backup",
          level: :error,
          description: "Failed to restore backup: #{importer.error_message}"
        )
        false
      end

    rescue StandardError => e
      ActivityLog.create!(
        action: "restore",
        target: "backup",
        level: :error,
        description: "Failed to restore backup: #{e.message}"
      )
      false
    ensure
      # Clean up temporary files
      FileUtils.rm_f(temp_zip)
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    end
  end

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

  def upload_to_s3(backup_zip, timestamp)
    return unless s3_enabled && s3_client

    File.open(backup_zip, "rb") do |file|
      key = File.join(
        s3_prefix,
        timestamp[0..3],  # Year
        timestamp[4..5],  # Month
        File.basename(backup_zip)
      )

      s3_client.put_object(
        bucket: s3_bucket,
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

  def cleanup_old_backups
    return unless s3_enabled && s3_client && backup_retention_days.present?

    prefix = s3_prefix.present? ? "#{s3_prefix}/" : ""
    objects = s3_client.list_objects_v2(bucket: s3_bucket, prefix: prefix)

    retention_date = Time.current - backup_retention_days.days
    objects.contents.each do |obj|
      if obj.last_modified < retention_date
        s3_client.delete_object(bucket: s3_bucket, key: obj.key)
        ActivityLog.create!(
          action: "backup",
          target: "backup",
          level: :info,
          description: "Deleted old backup: #{obj.key}"
        )
      end
    end
  end

  def cleanup_temp_files
    temp_dir = Rails.root.join("storage", "backup", "temp")
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  private

  def set_defaults
    self.s3_prefix ||= "backups"
    self.s3_enabled ||= false
    self.auto_backup ||= false
    self.backup_interval_hours ||= 24
    self.backup_retention_days ||= 30
  end
end
