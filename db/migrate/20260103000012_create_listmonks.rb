class CreateListmonks < ActiveRecord::Migration[8.1]
  def change
    create_table :listmonks do |t|
      t.boolean :enabled, default: false, null: false
      t.string :username
      t.string :api_key
      t.string :url
      t.integer :list_id
      t.integer :template_id

      t.timestamps
    end
  end
end

