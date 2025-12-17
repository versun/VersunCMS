class AddStaticGenerationDestinationToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :static_generation_destination, :string, default: "local"
  end
end
