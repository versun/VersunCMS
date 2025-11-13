class InitialSchema < ActiveRecord::Migration[8.0]
  def change
    # PostgreSQL extensions
    enable_extension "pg_trgm"

    # Core tables
    create_table :users do |t|
      t.string :user_name, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :user_name, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :articles do |t|
      t.string :title
      t.string :slug
      t.string :description
      t.integer :status, default: 0, null: false  # draft: 0, published: 1
      t.datetime :scheduled_at
      t.boolean :crosspost_mastodon, default: false, null: false
      t.boolean :crosspost_twitter, default: false, null: false
      t.boolean :crosspost_bluesky, default: false, null: false
      t.boolean :send_newsletter, default: false, null: false
      t.timestamps
    end
    add_index :articles, :slug, unique: true

    create_table :pages do |t|
      t.string :title
      t.string :slug
      t.integer :status, default: 0, null: false  # draft: 0, published: 1
      t.integer :page_order, default: 0, null: false
      t.string :redirect_url
      t.timestamps
    end
    add_index :pages, :slug, unique: true

    create_table :crossposts do |t|
      t.string :platform, null: false  # mastodon, twitter, bluesky
      t.string :server_url
      t.string :access_token
      t.string :access_token_secret
      t.string :client_key
      t.string :username
      t.string :api_key
      t.string :api_key_secret
      t.string :app_password
      t.boolean :enabled, default: false, null: false
      t.text :settings
      t.timestamps
    end
    add_index :crossposts, :platform, unique: true

    create_table :social_media_posts do |t|
      t.string :platform, null: false
      t.string :url, null: false
      t.references :article, null: false, foreign_key: true
      t.timestamps
    end
    add_index :social_media_posts, [ :article_id, :platform ], unique: true

    create_table :settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :settings, :key, unique: true

    create_table :activity_logs do |t|
      t.string :action
      t.string :target
      t.text :description
      t.integer :level, default: 0
      t.timestamps
    end

    create_table :listmonks do |t|
      t.boolean :enabled, default: false, null: false
      t.string :username
      t.string :api_key
      t.string :url
      t.integer :list_id
      t.integer :template_id
      t.timestamps
    end

    create_table :pg_search_documents do |t|
      t.text :content
      t.belongs_to :searchable, polymorphic: true, index: true
      t.timestamps null: false
    end

    # Action Text tables
    create_table :action_text_rich_texts do |t|
      t.string :name, null: false
      t.text :body, size: :long
      t.references :record, null: false, polymorphic: true, index: false
      t.timestamps
      t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
    end

    # Active Storage tables
    create_table :active_storage_blobs do |t|
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum
      t.datetime :created_at, null: false
      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob, null: false
      t.datetime :created_at, null: false
      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false
      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end
end
