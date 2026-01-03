class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :article, foreign_key: true, type: :integer
      t.string :platform
      t.string :external_id
      t.string :author_name, null: false
      t.string :author_username
      t.string :author_avatar_url
      t.string :author_url
      t.text :content, null: false
      t.datetime :published_at
      t.string :url
      t.integer :status, default: 0, null: false
      t.references :parent, foreign_key: { to_table: :comments, on_delete: :cascade }, type: :integer
      t.references :commentable, polymorphic: true, type: :integer

      t.timestamps
    end

    add_index :comments, [ :article_id, :platform, :external_id ],
              unique: true,
              where: "platform IS NOT NULL AND external_id IS NOT NULL",
              name: "index_comments_on_article_platform_external_id"
  end
end

