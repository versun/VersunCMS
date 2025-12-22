class SimplifyDeploySettings < ActiveRecord::Migration[8.1]
  def change
    # Add simplified deploy fields to settings
    add_column :settings, :deploy_provider, :string  # github, gitlab, gitea, codeberg, bitbucket, local
    add_column :settings, :deploy_repo_url, :string  # Repository URL
    add_column :settings, :deploy_branch, :string, default: "main"  # Target branch
  end
end
