class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :slug
      t.string :description
      t.integer :status, default: 0, null: false  # draft: 0, published: 1
      t.datetime :scheduled_at
      t.boolean :crosspost_mastodon, default: false, null: false
      t.boolean :crosspost_twitter, default: false, null: false
      t.boolean :crosspost_bluesky, default: false, null: false
      t.boolean :send_newsletter, default: false, null: false

      t.timestamps
    end
    add_index :articles, :slug, unique: true
  end
end