class CreateBackupSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :backup_settings do |t|
      t.string :s3_bucket
      t.string :s3_region
      t.string :s3_access_key_id
      t.string :s3_secret_access_key
      t.string :s3_endpoint
      t.string :s3_prefix, default: 'backups'
      t.boolean :s3_enabled, default: false
      t.boolean :auto_backup, default: false
      t.boolean :data_changed, default: false
      t.integer :backup_interval_hours, default: 24
      t.integer :backup_retention_days, default: 30
      t.datetime :last_backup_at

      t.timestamps
    end
  end
end
