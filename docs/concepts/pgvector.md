# pgvector: vectors inside Postgres

**In one line:** pgvector adds a `vector` column type to Postgres and operators that measure how far apart two vectors are.

## What it adds

| Piece | Example | Meaning |
|---|---|---|
| Column type | `embedding vector(384)` | A list of exactly 384 floats |
| `<=>` | `a <=> b` | Cosine distance: 0 = same direction, 1 = unrelated, 2 = opposite |
| `<->` | `a <-> b` | Euclidean (straight-line) distance |
| `<#>` | `a <#> b` | Negative inner product |
| Index | `USING hnsw (embedding vector_cosine_ops)` | Makes "nearest vectors" fast without scanning every row |

## Try it

```sql
SELECT '[1,0,0]'::vector <=> '[2,0,0]'::vector;  -- 0: same direction
SELECT '[1,0,0]'::vector <=> '[0,1,0]'::vector;  -- 1: unrelated
```

## In Rails

The `neighbor` gem maps the column type and gives models a query method:

```ruby
class Chunk < ApplicationRecord
  has_neighbors :embedding
end

Chunk.nearest_neighbors(:embedding, query_vector, distance: "cosine").first(5)
```

## Why cosine?

Cosine distance compares direction, not length. Two texts about "sync errors" point the same way in embedding space whether the post is long or short. Our embedding model returns unit-length vectors, so cosine and inner product rank results the same way.

See also: [when a vector DB helps, and when it does not](vector-databases.md).
