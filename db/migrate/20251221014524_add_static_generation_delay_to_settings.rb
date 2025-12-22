class AddStaticGenerationDelayToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :static_generation_delay, :string
  end
end
