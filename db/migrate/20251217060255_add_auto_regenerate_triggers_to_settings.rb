class AddAutoRegenerateTriggersToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :auto_regenerate_triggers, :json, default: []
  end
end
