class AddToolCodeToSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :settings, :tool_code, :text, null: true
  end
end
