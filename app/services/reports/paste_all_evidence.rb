module Reports
  # The paste-all arm's evidence: no search at all, every chunk of the
  # week goes into the prompt, grouped by thread so it reads in order.
  #
  # This is the obvious alternative to RAG when a week fits in the model's
  # context (about 50,000 tokens here). It gets the same SQL signals as the
  # RAG arm (trend counts, releases), so predictions can be compared too;
  # what differs is only how this week's posts reach the model.
  class PasteAllEvidence
    def initialize(signals: Signals.new) = @signals = signals

    def call(week, themes)
      evidence = Evidence.new
      Chunk.joins(:post).where(posts: { posted_at: week.range }).preload(post: :topic)
           .order("posts.topic_id", "posts.posted_at", :position)
           .each { evidence.add(_1, theme: Evidence::WHOLE_WEEK) }
      @signals.call(week, themes, evidence)
    end
  end
end
