class CreateRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :redirects do |t|
      t.string :regex, null: false
      t.string :replacement, null: false
      t.boolean :permanent, default: false
      t.boolean :enabled, default: true

      t.timestamps
    end

    add_index :redirects, :enabled
  end
end

