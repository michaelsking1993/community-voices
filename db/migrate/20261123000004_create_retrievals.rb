# Every retrieval is logged: one `retrievals` row per query, one
# `retrieval_hits` row per chunk it returned. That gives us retrieval
# stats (which chunks get used most, how often a query finds nothing)
# with plain SQL, and lets the A/B page show exactly what each arm saw.
class CreateRetrievals < ActiveRecord::Migration[8.1]
  def change
    create_table :retrievals do |t|
      t.text :query, null: false
      t.string :purpose, null: false, default: "adhoc"
      t.datetime :window_start
      t.datetime :window_end
      t.integer :k, null: false
      t.integer :per_topic, null: false
      t.float :max_distance, null: false
      t.integer :candidates_count, null: false
      t.integer :hits_count, null: false
      t.integer :duration_ms, null: false
      t.datetime :created_at, null: false
    end
    add_index :retrievals, [ :purpose, :created_at ]

    create_table :retrieval_hits do |t|
      t.references :retrieval, null: false, foreign_key: { on_delete: :cascade }
      t.references :chunk, null: false, foreign_key: { on_delete: :cascade }
      t.integer :rank, null: false
      t.float :distance, null: false
    end
  end
end
