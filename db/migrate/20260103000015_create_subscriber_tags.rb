class CreateSubscriberTags < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriber_tags do |t|
      t.references :subscriber, null: false, foreign_key: true, type: :integer
      t.references :tag, null: false, foreign_key: true, type: :integer

      t.timestamps
    end

    add_index :subscriber_tags, [ :subscriber_id, :tag_id ], unique: true
  end
end

