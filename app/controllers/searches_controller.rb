# Semantic search over the stored forum posts: the same Search::Retriever the
# report uses (0.6 distance cut-off, at most 2 chunks per thread), with no date
# window. Unlike the report it is not limited to 8 hits: it lists every chunk
# inside the cut-off, up to the retriever's candidate pool of 100. Needs no LLM key, because embedding runs locally.
class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    @result = Search::Retriever.new.call(@query, k: Search::Retriever::CANDIDATES, purpose: "search") if @query.present?
  end
end
