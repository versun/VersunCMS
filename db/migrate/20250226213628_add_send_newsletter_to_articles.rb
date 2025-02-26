class AddSendNewsletterToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :send_newsletter, :boolean, default: false, null: false
  end
end
