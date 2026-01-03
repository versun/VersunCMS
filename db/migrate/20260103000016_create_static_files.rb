class CreateStaticFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :static_files do |t|
      t.text :description
      t.text :filename

      t.timestamps
    end

    add_index :static_files, :filename, unique: true
  end
end

