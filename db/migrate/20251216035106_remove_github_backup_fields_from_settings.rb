class RemoveGithubBackupFieldsFromSettings < ActiveRecord::Migration[8.1]
  def change
    remove_column :settings, :github_backup_enabled, :boolean
    remove_column :settings, :github_repo_url, :string
    remove_column :settings, :github_token, :string
    remove_column :settings, :github_backup_branch, :string
    remove_column :settings, :github_backup_schedule, :string
    remove_column :settings, :git_user_name, :string
    remove_column :settings, :git_user_email, :string
    remove_column :settings, :last_backup_at, :datetime
  end
end
