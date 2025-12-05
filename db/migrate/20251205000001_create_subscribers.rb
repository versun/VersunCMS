class CreateSubscribers < ActiveRecord::Migration[8.0]
  def change
    create_table :subscribers do |t|
      t.string :email, null: false
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at
      t.string :confirmation_token
      t.string :unsubscribe_token

      t.timestamps
    end

    add_index :subscribers, :email, unique: true
    add_index :subscribers, :confirmation_token, unique: true
    add_index :subscribers, :unsubscribe_token, unique: true
  end
end
