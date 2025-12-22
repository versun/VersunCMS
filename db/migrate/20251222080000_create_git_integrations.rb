class CreateGitIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :git_integrations do |t|
      t.string :provider, null: false  # github, gitlab, gitea, codeberg, bitbucket
      t.string :name, null: false      # Display name for the integration
      t.string :server_url             # Base URL for self-hosted (GitLab, Gitea)
      t.string :username               # Bitbucket username (for App Password)
      t.string :access_token           # Personal Access Token or App Password
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end

    add_index :git_integrations, :provider, unique: true
  end
end
