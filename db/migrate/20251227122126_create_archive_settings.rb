class CreateArchiveSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :archive_settings do |t|
      t.references :git_integration, foreign_key: true
      t.string :repo_url
      t.string :branch, default: "main"
      t.boolean :auto_archive_published_articles, default: false, null: false
      t.boolean :auto_archive_article_links, default: false, null: false
      t.boolean :auto_submit_to_archive_org, default: false, null: false
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end
  end
end
