# Stamps every chunk with the model that made its embedding. Vectors from
# two models live on different "maps" and cannot be compared, even when
# they have the same length, so the app needs to know which is which.
#
# Every embedding so far came from all-MiniLM-L6-v2, so existing rows are
# stamped with it.
class AddEmbeddingModelToChunks < ActiveRecord::Migration[8.1]
  def up
    add_column :chunks, :embedding_model, :string
    execute "UPDATE chunks SET embedding_model = 'Xenova/all-MiniLM-L6-v2' WHERE embedding IS NOT NULL"
  end

  def down
    remove_column :chunks, :embedding_model
  end
end
