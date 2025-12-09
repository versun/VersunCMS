class AddContentTypeToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :content_type, :string, default: 'rich_text', null: false
    add_column :articles, :html_content, :text
  end
end
