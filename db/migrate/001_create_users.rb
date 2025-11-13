class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :user_name, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :user_name, unique: true
  end
end