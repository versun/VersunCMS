class CreateActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_logs do |t|
      t.string :action
      t.string :target
      t.text :description
      t.integer :level, default: 0

      t.timestamps
    end
  end
end

