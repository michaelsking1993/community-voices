# Semantic search over the stored forum posts: the same Search::Retriever the
# report uses (0.6 distance cut-off, at most 2 chunks per thread), with no date
# window. Needs no LLM key, because embedding runs locally.
class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    @result = Search::Retriever.new.call(@query, purpose: "search") if @query.present?
  end
end
