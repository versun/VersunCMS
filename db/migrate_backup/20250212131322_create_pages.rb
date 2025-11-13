class CreatePages < ActiveRecord::Migration[8.0]
  def change
    create_table :pages do |t|
      t.string :title
      t.string :slug
      t.integer :status, default: :draft, null: false
      t.integer :page_order, default: 0, null: false

      t.timestamps
    end
    add_index :pages, :slug, unique: true
  end
end
