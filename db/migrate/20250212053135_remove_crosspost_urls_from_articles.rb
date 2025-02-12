class RemoveCrosspostUrlsFromArticles < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:articles, :crosspost_urls)
      remove_column :articles, :crosspost_urls
    end
  end
end
