class AddCommentToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :comment, :boolean, default: false, null: false
  end
end
