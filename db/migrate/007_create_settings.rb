class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.string :title
      t.text :description
      t.string :author
      t.string :url
      t.string :time_zone, default: "UTC"
      t.text :head_code
      t.text :custom_css
      t.text :tool_code
      t.text :giscus
      t.json :social_links
      t.json :static_files, default: {}

      t.timestamps
    end
  end
end