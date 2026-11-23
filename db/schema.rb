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

ActiveRecord::Schema[8.1].define(version: 2026_11_23_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "chunks", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.integer "position", null: false
    t.text "content", null: false
    t.string "content_hash", null: false
    t.integer "token_estimate", null: false
    t.vector "embedding", limit: 384
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["post_id", "position"], name: "index_chunks_on_post_id_and_position", unique: true
    t.index ["post_id"], name: "index_chunks_on_post_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.bigint "discourse_id", null: false
    t.integer "post_number", null: false
    t.integer "reply_to_post_number"
    t.string "username", null: false
    t.text "raw", null: false
    t.datetime "posted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discourse_id"], name: "index_posts_on_discourse_id", unique: true
    t.index ["posted_at"], name: "index_posts_on_posted_at"
    t.index ["topic_id"], name: "index_posts_on_topic_id"
  end

  create_table "retrieval_hits", force: :cascade do |t|
    t.bigint "retrieval_id", null: false
    t.bigint "chunk_id", null: false
    t.integer "rank", null: false
    t.float "distance", null: false
    t.index ["chunk_id"], name: "index_retrieval_hits_on_chunk_id"
    t.index ["retrieval_id"], name: "index_retrieval_hits_on_retrieval_id"
  end

  create_table "retrievals", force: :cascade do |t|
    t.text "query", null: false
    t.string "purpose", default: "adhoc", null: false
    t.datetime "window_start"
    t.datetime "window_end"
    t.integer "k", null: false
    t.integer "per_topic", null: false
    t.float "max_distance", null: false
    t.integer "candidates_count", null: false
    t.integer "hits_count", null: false
    t.integer "duration_ms", null: false
    t.datetime "created_at", null: false
    t.index ["purpose", "created_at"], name: "index_retrievals_on_purpose_and_created_at"
  end

  create_table "topics", force: :cascade do |t|
    t.bigint "discourse_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.integer "category_id"
    t.string "category_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discourse_id"], name: "index_topics_on_discourse_id", unique: true
  end

  add_foreign_key "chunks", "posts"
  add_foreign_key "posts", "topics"
  add_foreign_key "retrieval_hits", "chunks", on_delete: :cascade
  add_foreign_key "retrieval_hits", "retrievals", on_delete: :cascade
end
