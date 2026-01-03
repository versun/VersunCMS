class CreateGitIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :git_integrations do |t|
      t.string :provider, null: false
      t.string :name, null: false
      t.string :server_url
      t.string :username
      t.string :access_token
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end

    add_index :git_integrations, :provider, unique: true
  end
end

