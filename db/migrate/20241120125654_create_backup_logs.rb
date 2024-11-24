class CreateBackupLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :backup_logs do |t|
      t.integer :status, null: false, default: 0
      t.text :message

      t.timestamps
    end
  end
end
