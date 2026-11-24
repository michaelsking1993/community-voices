namespace :backtest do
  desc "Score the predictions of the last N weeks against what happened next (default 4). Example: bin/rails 'backtest:run[4]'"
  task :run, [ :weeks ] => :environment do |_, args|
    puts Pipeline::Runner.new.call("backtest", weeks: (args[:weeks] || 4).to_i)
  end
end
