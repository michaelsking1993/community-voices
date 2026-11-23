# A chunk is a slice of one post, with a short header, plus its embedding.
# The HNSW index makes "nearest chunks by cosine distance" fast without
# scanning every row.
class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :chunks do |t|
      t.references :post, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :content, null: false
      t.string :content_hash, null: false
      t.integer :token_estimate, null: false
      t.vector :embedding, limit: 384
      t.timestamps
    end
    add_index :chunks, [ :post_id, :position ], unique: true
    add_index :chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
