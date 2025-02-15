class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.string :title, null: true
      t.text :description, null: true
      t.string :author, null: true
      t.string :url, null: true
      t.string :time_zone, null: true, default: "UTC"
      t.text :head_code, null: true
      t.text :custom_css, null: true
      t.json :social_links, null: true
      t.json :static_files, null: true, default: {}

      t.timestamps
    end
  end
end
