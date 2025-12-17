class AddLocalGenerationPathToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :local_generation_path, :string

    # Set default value for existing records
    reversible do |dir|
      dir.up do
        default_path = Rails.root.join("public").to_s
        execute <<-SQL
          UPDATE settings SET local_generation_path = '#{default_path}' WHERE local_generation_path IS NULL;
        SQL
      end
    end
  end
end
