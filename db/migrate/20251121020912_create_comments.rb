class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :article, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :external_id, null: false
      t.string :author_name
      t.string :author_username
      t.string :author_avatar_url
      t.text :content
      t.datetime :published_at
      t.string :url

      t.timestamps
    end
    add_index :comments, [ :article_id, :platform, :external_id ], unique: true
  end
end
