namespace :backtest do
  desc "Score the predictions of the last N weeks against what happened next (default 4). Example: bin/rails 'backtest:run[4]'"
  task :run, [ :weeks ] => :environment do |_, args|
    judge = Llm.client(model: ENV["LLM_JUDGE_MODEL"].presence || ENV["LLM_MODEL"].presence)
    run = Backtest::Run.new(scorer: Backtest::Scorer.new(llm: judge))
    weeks = run.weeks((args[:weeks] || 4).to_i)
    puts "Backtest over #{weeks.size} weeks: each report uses only data from before the week it predicts."
    judgements = run.call(weeks)
    summary = Backtest::Summary.new(judgements)
    [ [ "overall", [ summary.overall ] ], [ "by confidence", summary.by_confidence ], [ "by basis", summary.by_basis ] ].each do |title, rows|
      puts "\n#{title}"
      rows.each do |r|
        puts format("  %-10s scored %2d  hit rate %-5s (happened %d, partly %d, did not %d, could not tell %d)",
                    r.label, r.scored, r.hit_rate.inspect, r.happened, r.partly, r.did_not_happen, r.no_evidence)
      end
    end
    cost = judgements.sum { _1.cost_usd.to_f }
    puts "\nJudge cost: ~$#{cost.round(2)} (report cost is on each report)"
  end
end
