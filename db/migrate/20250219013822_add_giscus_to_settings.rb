class AddGiscusToSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :settings, :giscus, :text, null: true
  end
end
