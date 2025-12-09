class AddHtmlContentToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :html_content, :text
    add_column :pages, :content_type, :string, default: 'rich_text', null: false
  end
end
