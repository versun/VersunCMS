class AddGithubBackupSettingsToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :github_backup_enabled, :boolean, default: false
    add_column :settings, :github_repo_url, :string
    add_column :settings, :github_token, :string
    add_column :settings, :github_backup_branch, :string, default: "main"
    add_column :settings, :github_backup_cron, :string
    add_column :settings, :git_user_name, :string
    add_column :settings, :git_user_email, :string
    add_column :settings, :last_backup_at, :datetime
  end
end
