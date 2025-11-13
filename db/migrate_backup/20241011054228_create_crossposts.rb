class CreateCrossposts < ActiveRecord::Migration[8.0]
  def change
    create_table :crossposts do |t|
      t.string :platform, null: false  # mastodon or twitter
      t.string :server_url  # for mastodon
      t.string :access_token
      t.string :access_token_secret
      t.string :client_id
      t.string :client_secret
      t.boolean :enabled, default: false, null: false
      t.text :settings # for additional settings in JSON format

      t.timestamps
    end

    add_index :crossposts, :platform, unique: true
  end
end
