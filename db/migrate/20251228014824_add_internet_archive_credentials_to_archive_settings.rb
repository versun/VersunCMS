class AddInternetArchiveCredentialsToArchiveSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :archive_settings, :ia_access_key, :string
    add_column :archive_settings, :ia_secret_key, :string
  end
end
