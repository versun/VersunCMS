class DropArchiveTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :archive_items, if_exists: true
    drop_table :archive_settings, if_exists: true
  end
end
