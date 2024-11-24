class CreateVirtualArticleFts < ActiveRecord::Migration[8.0]
  def change
    create_virtual_table :article_fts, :fts5, [ "content", "title" ]
  end
end
