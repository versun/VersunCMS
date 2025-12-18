class AddSourceFieldsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :source_url, :string
    add_column :articles, :source_archive_url, :string
    add_column :articles, :source_author, :string
    add_column :articles, :source_content, :text
  end
end
