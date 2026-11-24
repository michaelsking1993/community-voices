module Reports
  # The paste-all arm's evidence: no search, no themes. Every post of the
  # week goes into the prompt once, cleaned the same way chunks are (quotes,
  # images and code removed), grouped by thread so each title appears once.
  #
  # This is the obvious alternative to RAG when a week fits in the model's
  # context (about 50,000 tokens). Posts, not chunks: chunks overlap and
  # repeat a header, which would inflate this arm's cost.
  class PasteAllEvidence
    def call(week, _themes)
      evidence = Evidence.new
      Post.posted_between(week.range.begin, week.range.end).preload(:topic).order(:topic_id, :posted_at).each do |post|
        text = Chunking::TextCleaner.call(post.raw)
        evidence.add_post(post, text, theme: Evidence::WHOLE_WEEK) if text.present?
      end
      evidence
    end
  end
end
