class AddSetupCompletedToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :setup_completed, :boolean, default: false

    # For existing installations with users, mark setup as completed
    reversible do |dir|
      dir.up do
        if User.exists?
          Setting.update_all(setup_completed: true)
        end
      end
    end
  end
end
