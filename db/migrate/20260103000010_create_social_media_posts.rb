class CreateSocialMediaPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_media_posts do |t|
      t.string :platform, null: false
      t.string :url, null: false
      t.references :article, null: false, foreign_key: true, type: :integer

      t.timestamps
    end

    add_index :social_media_posts, [ :article_id, :platform ], unique: true
  end
end

