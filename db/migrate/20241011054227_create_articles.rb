class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :slug
      t.integer :status, default: :draft, null: false
      t.boolean :is_page, default: false, null: false
      t.integer :page_order, default: 0, null: false
      t.datetime :scheduled_at, null: true
      t.boolean :crosspost_mastodon, default: false, null: false
      t.boolean :crosspost_twitter, default: false, null: false

      t.timestamps
    end
    add_index :articles, :slug, unique: true
  end
end
