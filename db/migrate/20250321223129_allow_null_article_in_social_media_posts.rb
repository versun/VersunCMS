class AllowNullArticleInSocialMediaPosts < ActiveRecord::Migration[8.0]
  def change
    change_column_null :social_media_posts, :article_id, true
  end
end
