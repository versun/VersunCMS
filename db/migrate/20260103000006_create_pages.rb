class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.string :title
      t.string :slug
      t.integer :status, default: 0, null: false
      t.integer :page_order, default: 0, null: false
      t.string :redirect_url
      t.text :html_content
      t.string :content_type, default: "rich_text", null: false
      t.boolean :comment, default: false, null: false

      t.timestamps
    end

    add_index :pages, :slug, unique: true
  end
end

