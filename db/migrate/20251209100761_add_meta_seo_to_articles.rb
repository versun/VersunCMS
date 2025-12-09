class AddMetaSeoToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :meta_title, :string
    add_column :articles, :meta_description, :text
    add_column :articles, :meta_image, :string
  end
end
