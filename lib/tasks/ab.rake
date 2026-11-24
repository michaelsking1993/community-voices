namespace :ab do
  desc "A/B test the last N complete weeks: no context vs paste-all vs RAG (default 1). Example: bin/rails 'ab:run[2]'"
  task :run, [ :weeks ] => :environment do |_, args|
    puts Pipeline::Runner.new.call("ab", weeks: (args[:weeks] || 1).to_i)
  end
end
