class AddAuthorEmailToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :author_email, :string
  end
end
