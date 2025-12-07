class ChangeGithubBackupCronToSchedule < ActiveRecord::Migration[8.1]
  def up
    # Rename column from github_backup_cron to github_backup_schedule
    rename_column :settings, :github_backup_cron, :github_backup_schedule
    
    # Convert existing cron values to weekly schedule if any exist
    # This is a one-time data migration
    Setting.find_each do |setting|
      if setting.github_backup_schedule.present?
        # Directly set to weekly for all existing cron values
        setting.update_column(:github_backup_schedule, 'weekly')
      end
    end
  end

  def down
    # Clear all schedule values before renaming column back
    Setting.find_each do |setting|
      if setting.github_backup_schedule.present?
        setting.update_column(:github_backup_schedule, nil)
      end
    end
    
    # Rename column back
    rename_column :settings, :github_backup_schedule, :github_backup_cron
  end
end

