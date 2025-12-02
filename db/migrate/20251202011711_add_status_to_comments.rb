class AddStatusToComments < ActiveRecord::Migration[8.1]
  def up
    add_column :comments, :status, :integer, default: 0, null: false

    # Migrate existing data
    Comment.where(approved: true).update_all(status: 1) # approved
    Comment.where(approved: false).update_all(status: 0) # pending

    remove_column :comments, :approved
  end

  def down
    add_column :comments, :approved, :boolean, default: false, null: false

    # Migrate data back
    Comment.where(status: 1).update_all(approved: true)
    Comment.where(status: [ 0, 2 ]).update_all(approved: false) # pending and rejected become unapproved

    remove_column :comments, :status
  end
end
