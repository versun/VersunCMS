class CreateStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :statuses do |t|
      t.string :text
      t.boolean :crosspost_mastodon, default: true, null: false
      t.boolean :crosspost_twitter, default: true, null: false
      t.boolean :crosspost_bluesky, default: true, null: false
      t.json :crosspost_urls, default: {}, null: false

      t.timestamps
    end
  end
end
