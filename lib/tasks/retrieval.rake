namespace :retrieval do
  desc "Search like the report does (window, cut-off, max 2 per thread). Example: bin/rails 'retrieval:search[sync problems]'"
  task :search, [ :query, :days ] => :environment do |_, args|
    window = args[:days] ? args[:days].to_i.days.ago..Time.current : nil
    result = Search::Retriever.new.call(args.fetch(:query), window:)
    puts "No chunk within distance #{Search::Retriever::MAX_DISTANCE}: not enough evidence." if result.empty?
    result.hits.each do |hit|
      puts format("%.3f  %s\n       %s", hit.distance, hit.chunk.post.url, hit.chunk.content.split("\n\n", 2).last.truncate(120))
    end
  end

  desc "Score retrieval on the hand-labelled queries in config/eval/retrieval.yml"
  task eval: :environment do
    evaluation = Search::Evaluation.new
    rows = evaluation.call(Search::Evaluation.cases)
    abort "None of the labelled threads are loaded. Run bin/rails 'ingest:backfill[12]' first." if rows.empty?

    rows.group_by(&:query).each do |query, by_config|
      puts query
      by_config.each { |r| puts format("  %-18s hit=%-5s recall=%.2f threads=%d", r.config, r.hit, r.recall, r.threads) }
    end
    puts "\nconfig              queries  hit rate  recall  threads in top #{Search::Retriever::K}"
    evaluation.summarize(rows).each do |s|
      puts format("%-18s  %7d  %8.2f  %6.2f  %7.1f", s.config, s.queries, s.hit_rate, s.recall, s.threads)
    end
    off_topic = Search::Evaluation.off_topic
    puts "\nOff-topic queries that correctly found nothing: #{(evaluation.off_topic_empty_rate(off_topic) * 100).round}% of #{off_topic.size}"
    Retrieval.where(purpose: "eval").delete_all # keep eval runs out of the retrieval stats
  end
end
