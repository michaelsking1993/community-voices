module Reports
  # The numbered evidence a report is written from. Each item is one chunk
  # with an id like "E3" that the model cites; code later checks every
  # citation and quote against these items.
  class Evidence
    Item = Data.define(:id, :chunk_id, :post_id, :url, :title, :category, :date, :text, :theme, :history) do
      def self.from_chunk(id, chunk, theme:, history: false)
        post = chunk.post
        new(id:, chunk_id: chunk.id, post_id: post.id, url: post.url, title: post.topic.title,
            category: post.topic.category_name, date: post.posted_at.to_date.iso8601,
            text: chunk.content.split("\n\n", 2).last, theme:, history:)
      end

      def to_prompt = "[#{id}] #{date} · #{category} · \"#{title}\"\n#{text}"
    end

    attr_reader :items

    def initialize(items = []) = @items = items

    def add(chunk, theme:, history: false)
      Item.from_chunk("E#{items.size + 1}", chunk, theme:, history:).tap { items << _1 }
    end

    def [](id) = items.find { _1.id == id }
    def for_theme(position, history: false) = items.select { _1.theme == position && _1.history == history }
    def empty? = items.none? { !_1.history }
    def to_h = items.to_h { [ _1.id, _1.to_h.except(:id) ] }

    def self.from_h(hash)
      new(hash.map { |id, attrs| Item.new(id:, **attrs.symbolize_keys) })
    end
  end
end
