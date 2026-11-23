# A theme is a group of forum threads from one week that are about the same
# thing, found by clustering their embeddings and then named by the model.
# Counts come from SQL, never from the model.
class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      t.date :week_start, null: false
      t.integer :position, null: false
      t.string :label, null: false
      t.text :summary, null: false
      t.string :kind, null: false
      t.vector :centroid, limit: 384, null: false
      t.integer :topic_count, null: false
      t.integer :post_count, null: false
      t.integer :author_count, null: false
      t.timestamps
    end
    add_index :themes, [ :week_start, :position ], unique: true

    create_table :theme_topics do |t|
      t.references :theme, null: false, foreign_key: { on_delete: :cascade }
      t.references :topic, null: false, foreign_key: true
      t.float :similarity, null: false
      t.integer :post_count, null: false
    end
    add_index :theme_topics, [ :theme_id, :topic_id ], unique: true
  end
end
