class CreateListmonks < ActiveRecord::Migration[8.0]
  def change
    create_table :listmonks do |t|
      t.string :api_key
      t.string :url
      t.integer :list_id

      t.timestamps
    end
  end
end
