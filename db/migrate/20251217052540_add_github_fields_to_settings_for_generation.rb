class AddGithubFieldsToSettingsForGeneration < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :github_repo_url, :string
    add_column :settings, :github_token, :string
    add_column :settings, :github_backup_branch, :string, default: "main"
    add_column :settings, :github_backup_enabled, :boolean, default: false
  end
end
