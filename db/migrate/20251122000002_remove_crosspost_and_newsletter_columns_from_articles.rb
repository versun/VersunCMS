class RemoveCrosspostAndNewsletterColumnsFromArticles < ActiveRecord::Migration[8.0]
  def change
    remove_column :articles, :crosspost_mastodon, :boolean
    remove_column :articles, :crosspost_twitter, :boolean
    remove_column :articles, :crosspost_bluesky, :boolean
    remove_column :articles, :send_newsletter, :boolean
  end
end
