module Chunking
  # Splits one post into overlapping word windows, each prefixed with a
  # header naming its topic, category and date, and saves them as chunks.
  #
  # - Tiny posts ("thanks, that worked!") are skipped: they carry no
  #   content and would crowd search results with near-identical vectors.
  # - Each chunk stores a SHA-256 of its text. If the text is unchanged its
  #   embedding is kept; if it changed, the embedding is cleared so the
  #   Embedder redoes only that chunk.
  class Chunker
    MIN_WORDS = 12     # below this a post is skipped
    WINDOW_WORDS = 150 # the model reads up to ~256 word-pieces; 150 words + header fits
    OVERLAP_WORDS = 30 # so a sentence cut at a boundary still appears whole in one chunk
    CHARS_PER_TOKEN = 4

    def call(post)
      texts = chunk_texts(post)
      existing = post.chunks.index_by(&:position)

      texts.each_with_index do |content, position|
        save(post, existing[position], position, content)
      end
      post.chunks.where(position: texts.size..).delete_all # post got shorter
      texts.size
    end

    def chunk_texts(post)
      words = TextCleaner.call(post.raw).split
      return [] if words.size < MIN_WORDS

      step = WINDOW_WORDS - OVERLAP_WORDS
      starts = (0...words.size).step(step).take_while { |i| i.zero? || i + OVERLAP_WORDS < words.size }
      starts.map { |i| "#{header(post)}\n\n#{words[i, WINDOW_WORDS].join(" ")}" }
    end

    private

    def header(post)
      topic = post.topic
      [ "Topic: #{topic.title}", "Category: #{topic.category_name || "Uncategorized"}", "Date: #{post.posted_at.to_date.iso8601}" ].join("\n")
    end

    def save(post, chunk, position, content)
      digest = Digest::SHA256.hexdigest(content)
      return if chunk&.content_hash == digest # unchanged: keep the embedding

      chunk ||= post.chunks.build(position:)
      chunk.update!(content:, content_hash: digest, token_estimate: content.length / CHARS_PER_TOKEN, embedding: nil, embedding_model: nil)
    end
  end
end
