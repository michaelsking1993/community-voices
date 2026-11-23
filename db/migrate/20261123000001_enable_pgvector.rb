# pgvector adds a `vector` column type and distance operators to Postgres,
# so embeddings live next to the posts they came from.
class EnablePgvector < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"
  end
end
