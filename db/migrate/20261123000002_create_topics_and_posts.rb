# Topics and posts mirror the forum's own ids (discourse_id), so running
# the crawler twice updates rows instead of duplicating them.
class CreateTopicsAndPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      t.bigint :discourse_id, null: false
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :category_id
      t.string :category_name
      t.timestamps
    end
    add_index :topics, :discourse_id, unique: true

    create_table :posts do |t|
      t.references :topic, null: false, foreign_key: true
      t.bigint :discourse_id, null: false
      t.integer :post_number, null: false
      t.integer :reply_to_post_number
      t.string :username, null: false
      t.text :raw, null: false
      t.datetime :posted_at, null: false
      t.timestamps
    end
    add_index :posts, :discourse_id, unique: true
    add_index :posts, :posted_at
  end
end
