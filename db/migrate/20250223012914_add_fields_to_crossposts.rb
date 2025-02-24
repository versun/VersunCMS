class AddFieldsToCrossposts < ActiveRecord::Migration[8.0]
  def change
    add_column :crossposts, :client_key, :string
    add_column :crossposts, :username, :string
    add_column :crossposts, :api_key, :string
    add_column :crossposts, :api_key_secret, :string
    add_column :crossposts, :app_password, :string
  end
end
