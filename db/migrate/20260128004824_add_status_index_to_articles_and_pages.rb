class AddStatusIndexToArticlesAndPages < ActiveRecord::Migration[8.1]
  def change
    add_index :articles, :status
    add_index :pages, :status
  end
end
