class CreateActiveStorageVariantRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :active_storage_variant_records do |t|
      t.bigint :blob_id, null: false
      t.string :variation_digest, null: false

      t.index [ :blob_id, :variation_digest ], name: "index_active_storage_variant_records_uniqueness", unique: true
    end

    add_foreign_key :active_storage_variant_records, :active_storage_blobs, column: :blob_id
  end
end

