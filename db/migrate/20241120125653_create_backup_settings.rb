class CreateBackupSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :backup_settings do |t|
      t.string :repository_url, null: false
      t.string :branch_name, null: false, default: 'main'
      t.text :ssh_public_key
      t.text :ssh_private_key
      t.string :git_name
      t.string :git_email
      t.boolean :auto_backup, default: false
      t.integer :backup_interval, default: 24
      t.datetime :last_backup_at
      t.json :log

      t.timestamps
    end
  end
end
