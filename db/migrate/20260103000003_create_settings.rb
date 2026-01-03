class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :title
      t.text :description
      t.string :author
      t.string :url
      t.string :time_zone, default: "UTC"
      t.text :head_code
      t.text :custom_css
      t.text :tool_code
      t.text :giscus
      t.json :social_links
      t.json :static_files, default: {}
      t.boolean :setup_completed, default: false
      t.string :deploy_provider
      t.string :deploy_repo_url
      t.string :deploy_branch, default: "main"
      t.string :github_repo_url
      t.string :github_token
      t.boolean :github_backup_enabled, default: false
      t.string :github_backup_branch, default: "main"
      t.string :static_generation_destination, default: "local"
      t.string :static_generation_delay
      t.string :local_generation_path
      t.json :auto_regenerate_triggers, default: []

      t.timestamps
    end
  end
end

