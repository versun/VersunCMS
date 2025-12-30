class CreateArchiveItems < ActiveRecord::Migration[8.1]
  def change
    create_table :archive_items do |t|
      t.string :url, null: false
      t.string :title
      t.integer :status, default: 0, null: false
      t.string :file_path
      t.integer :file_size
      t.datetime :archived_at
      t.text :error_message
      t.references :article, foreign_key: true

      t.timestamps
    end

    add_index :archive_items, :url, unique: true
    add_index :archive_items, :status
  end
end
