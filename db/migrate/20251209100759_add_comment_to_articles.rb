class AddCommentToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :comment, :boolean, default: false, null: false
  end
end
