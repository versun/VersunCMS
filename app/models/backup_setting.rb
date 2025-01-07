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
      # Download backup file
      temp_dir = Rails.root.join("storage", "backup", "temp")
      FileUtils.mkdir_p(temp_dir)
      temp_zip = File.join(temp_dir, "restore_backup.zip")

      s3_client.get_object(
        bucket: s3_bucket,
        key: backup_key,
        response_target: temp_zip
      )

      # Extract database file from zip
      db_path = Rails.configuration.database_configuration[Rails.env]["database"]
      temp_db = File.join(temp_dir, "temp.sqlite3")

      # Find and extract the database file
      db_found = false
      Zip::File.open(temp_zip) do |zip_file|
        zip_file.each do |entry|
          if entry.name == "production.sqlite3"
            entry.extract(temp_db)
            db_found = true
            break
          end
        end
      end

      unless db_found
        raise "Database file not found in backup archive"
      end

      # Create a backup of the current database
      backup_time = Time.current.strftime("%Y%m%d_%H%M%S")
      db_backup = "#{db_path}.backup_#{backup_time}"
      FileUtils.cp(db_path, db_backup) if File.exist?(db_path)

      # Close current database connections
      ActiveRecord::Base.connection.disconnect!

      begin
        # Replace the current database with the restored one
        FileUtils.mv(temp_db, db_path)

        # Reconnect to the database
        ActiveRecord::Base.establish_connection

        ActivityLog.create!(
          action: "restore",
          target: "backup",
          level: :info,
          description: "Successfully restored backup from #{backup_key}"
        )

        # Refresh all settings cache after restore
        SettingsService.refresh_all

        true
      rescue StandardError => e
        # If something goes wrong, try to restore the backup
        if File.exist?(db_backup)
          FileUtils.mv(db_backup, db_path)
          ActiveRecord::Base.establish_connection
        end
        raise e
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
      FileUtils.rm_f(temp_db)
    end
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
