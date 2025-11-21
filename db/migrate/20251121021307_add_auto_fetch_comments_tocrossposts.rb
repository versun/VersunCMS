class AddAutoFetchCommentsTocrossposts < ActiveRecord::Migration[8.1]
  def change
    add_column :crossposts, :auto_fetch_comments, :boolean, default: false, null: false
  end
end
