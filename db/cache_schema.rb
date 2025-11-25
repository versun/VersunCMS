# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_25_000001) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activity_logs", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "level", default: 0
    t.string "target"
    t.datetime "updated_at", null: false
  end

  create_table "articles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "scheduled_at"
    t.string "slug"
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.integer "article_id", null: false
    t.string "author_avatar_url"
    t.string "author_name"
    t.string "author_username"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "platform", null: false
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["article_id", "platform", "external_id"], name: "index_comments_on_article_id_and_platform_and_external_id", unique: true
    t.index ["article_id"], name: "index_comments_on_article_id"
  end

  create_table "crossposts", force: :cascade do |t|
    t.string "access_token"
    t.string "access_token_secret"
    t.string "api_key"
    t.string "api_key_secret"
    t.string "app_password"
    t.boolean "auto_fetch_comments", default: false, null: false
    t.string "client_key"
    t.string "client_secret"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.string "platform", null: false
    t.string "server_url"
    t.text "settings"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["platform"], name: "index_crossposts_on_platform", unique: true
  end

  create_table "listmonks", force: :cascade do |t|
    t.string "api_key"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.integer "list_id"
    t.integer "template_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "username"
  end

  create_table "pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "page_order", default: 0, null: false
    t.string "redirect_url"
    t.string "slug"
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_pages_on_slug", unique: true
  end

  create_table "redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true
    t.boolean "permanent", default: false
    t.string "regex", null: false
    t.string "replacement", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_redirects_on_enabled"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.text "custom_css"
    t.text "description"
    t.text "giscus"
    t.text "head_code"
    t.json "social_links"
    t.json "static_files", default: {}
    t.string "time_zone", default: "UTC"
    t.string "title"
    t.text "tool_code"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "social_media_posts", force: :cascade do |t|
    t.integer "article_id", null: false
    t.datetime "created_at", null: false
    t.string "platform", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["article_id", "platform"], name: "index_social_media_posts_on_article_id_and_platform", unique: true
    t.index ["article_id"], name: "index_social_media_posts_on_article_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", limit: 4, null: false
    t.datetime "created_at", null: false
    t.binary "key", limit: 1024, null: false
    t.integer "key_hash", limit: 8, null: false
    t.binary "value", limit: 536870912, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "static_files", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "filename"
    t.datetime "updated_at", null: false
    t.index ["filename"], name: "index_static_files_on_filename", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "articles"
  add_foreign_key "sessions", "users"
  add_foreign_key "social_media_posts", "articles"
end
