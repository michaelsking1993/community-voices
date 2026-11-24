# The four long tasks (crawl, retrieval eval, A/B test, backtest) as plain
# Ruby, so the rake tasks and the Evaluate tab run exactly the same code.
# Each returns the text a person would read, or raises Pipeline::Error.
module Pipeline
  class Error < StandardError; end

  class Runner
    def call(kind, weeks: nil)
      case kind
      when "ingest" then ingest(weeks || 2)
      when "retrieval_eval" then retrieval_eval
      when "ab" then ab(weeks || 1)
      when "backtest" then backtest(weeks || 4)
      else raise Error, "Unknown task #{kind.inspect}"
      end
    end

    private

    def ingest(weeks)
      return "Skipped (0 weeks)." if weeks.zero?

      since = Ingest::Coverage.new.crawl_from(weeks)
      crawled = Ingest::ForumCrawler.new.call(since:)
      transformed = Ingest::Transform.new.call(since:)
      "Crawled #{crawled.pages} pages from #{since.to_date}, saved #{crawled.posts_saved} posts.\n" \
        "#{transformed.posts} posts -> #{transformed.chunks} chunks, #{transformed.embedded} newly embedded."
    end

    def retrieval_eval
      evaluation = Search::Evaluation.new
      rows = evaluation.call(Search::Evaluation.cases)
      raise Error, "None of the labelled threads are loaded. Crawl 12 weeks first." if rows.empty?

      out = []
      rows.group_by(&:query).each do |query, by_config|
        out << query
        by_config.each { |r| out << format("  %-18s hit=%-5s recall=%.2f threads=%d", r.config, r.hit, r.recall, r.threads) }
      end
      out << "" << "config              queries  hit rate  recall  threads in top #{Search::Retriever::K}"
      evaluation.summarize(rows).each do |s|
        out << format("%-18s  %7d  %8.2f  %6.2f  %7.1f", s.config, s.queries, s.hit_rate, s.recall, s.threads)
      end
      off_topic = Search::Evaluation.off_topic
      out << "" << "Off-topic queries that correctly found nothing: #{(evaluation.off_topic_empty_rate(off_topic) * 100).round}% of #{off_topic.size}"
      Retrieval.where(purpose: "eval").delete_all # keep eval runs out of the retrieval stats
      out.join("\n")
    end

    def ab(weeks)
      run = Ab::Run.new(judge_llm: judge)
      Array.new(weeks) { |i| Week.last_complete.previous(i) }.reverse_each { |week| run.call(week) }
      out = [ format("%-10s %7s %7s %8s %6s %9s %8s %9s %8s", "arm", "in tok", "out tok", "cost $", "secs", "cites ok", "uncited", "supported", "wins") ]
      rows = Ab::Comparison.new.rows
      rows.each do |r|
        out << format("%-10s %7s %7s %8s %6s %9s %8s %9s %8s", r.arm, r.input_tokens, r.output_tokens, r.cost_usd, r.seconds,
                      r.citations_valid.inspect, r.sentences_uncited.inspect, r.support_rate.inspect, r.wins)
      end
      out << "Judge scores (1-5): " + rows.map { "#{_1.arm} #{_1.scores}" }.join(" | ")
      out.join("\n")
    end

    def backtest(weeks)
      run = Backtest::Run.new(scorer: Backtest::Scorer.new(llm: judge))
      scored_weeks = run.weeks(weeks)
      judgements = run.call(scored_weeks)
      summary = Backtest::Summary.new(judgements)
      out = [ "Backtest over #{scored_weeks.size} weeks: each report uses only data from before the week it predicts." ]
      [ [ "overall", [ summary.overall ] ], [ "by confidence", summary.by_confidence ], [ "by basis", summary.by_basis ] ].each do |title, rows|
        out << "" << title
        rows.each do |r|
          out << format("  %-10s scored %2d  hit rate %-5s (happened %d, partly %d, did not %d, could not tell %d)",
                        r.label, r.scored, r.hit_rate.inspect, r.happened, r.partly, r.did_not_happen, r.no_evidence)
        end
      end
      out << "" << "Judge cost: ~$#{judgements.sum { _1.cost_usd.to_f }.round(2)} (report cost is on each report)"
      out.join("\n")
    end

    def judge = Llm.client(model: ENV["LLM_JUDGE_MODEL"].presence || ENV["LLM_MODEL"].presence)
  end
end
