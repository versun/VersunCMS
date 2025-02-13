class RemoveIsPageAndPageOrderFromArticles < ActiveRecord::Migration[8.0]
  def change
    Article.where(is_page: true).in_batches.delete_all
    remove_column :articles, :is_page, :boolean
    remove_column :articles, :page_order, :integer
  end
end
