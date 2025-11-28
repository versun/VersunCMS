class UpdateCommentsForNativeSupport < ActiveRecord::Migration[8.1]
  def change
    # Make platform and external_id nullable to support native comments
    change_column_null :comments, :platform, true
    change_column_null :comments, :external_id, true

    # Make author_name and content required
    change_column_null :comments, :author_name, false
    change_column_null :comments, :content, false

    # Add author_url field for native comments
    add_column :comments, :author_url, :string

    # Add approved field for comment moderation
    add_column :comments, :approved, :boolean, default: false, null: false

    # Remove the old unique index
    remove_index :comments, name: "index_comments_on_article_id_and_platform_and_external_id"

    # Add new partial unique index (only for external comments)
    add_index :comments, [ :article_id, :platform, :external_id ],
              unique: true,
              where: "platform IS NOT NULL AND external_id IS NOT NULL",
              name: "index_comments_on_article_platform_external_id"
  end
end
