class RemoveSourceArchiveUrlFromArticles < ActiveRecord::Migration[8.1]
  def up
    remove_column :articles, :source_archive_url if column_exists?(:articles, :source_archive_url)
  end

  def down
    add_column :articles, :source_archive_url, :string unless column_exists?(:articles, :source_archive_url)
  end
end
