class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :slug
      t.string :description
      t.integer :status, default: 0, null: false
      t.datetime :scheduled_at
      t.boolean :comment, default: false, null: false
      t.string :content_type, default: "rich_text", null: false
      t.text :html_content
      t.string :meta_title
      t.text :meta_description
      t.string :meta_image
      t.string :source_url
      t.string :source_author
      t.text :source_content

      t.timestamps
    end

    add_index :articles, :slug, unique: true
  end
end

