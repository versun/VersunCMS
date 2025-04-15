class AddStatusToSocialMediaPosts < ActiveRecord::Migration[8.0]
  def change
    add_reference :social_media_posts, :status, null: true, foreign_key: true
  end
end
