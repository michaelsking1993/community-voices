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
    puts Pipeline::Runner.new.call("retrieval_eval")
  rescue Pipeline::Error => e
    abort e.message
  end
end
