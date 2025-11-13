class AddRedirectUrlToPages < ActiveRecord::Migration[8.0]
  def change
    add_column :pages, :redirect_url, :string
  end
end
