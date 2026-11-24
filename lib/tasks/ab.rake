namespace :ab do
  desc "A/B test the last N complete weeks: no context vs paste-all vs RAG (default 1). Example: bin/rails 'ab:run[2]'"
  task :run, [ :weeks ] => :environment do |_, args|
    judge = Llm.client(model: ENV["LLM_JUDGE_MODEL"].presence || ENV["LLM_MODEL"].presence)
    run = Ab::Run.new(judge_llm: judge)
    Array.new((args[:weeks] || 1).to_i) { |i| Week.last_complete.previous(i) }.reverse_each do |week|
      puts "Week #{week}: writing three reports, checking and ranking them..."
      run.call(week)
    end
    puts format("\n%-10s %7s %7s %8s %6s %9s %8s %9s %8s", "arm", "in tok", "out tok", "cost $", "secs", "cites ok", "uncited", "supported", "wins")
    rows = Ab::Comparison.new.rows
    rows.each do |r|
      puts format("%-10s %7s %7s %8s %6s %9s %8s %9s %8s", r.arm, r.input_tokens, r.output_tokens, r.cost_usd, r.seconds,
                  r.citations_valid.inspect, r.sentences_uncited.inspect, r.support_rate.inspect, r.wins)
    end
    puts "Judge scores (1-5): " + rows.map { "#{_1.arm} #{_1.scores}" }.join(" | ")
  end
end
