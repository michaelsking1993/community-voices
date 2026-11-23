namespace :themes do
  desc "Find and name a week's themes (default: last complete week). Example: bin/rails 'themes:find[2026-11-16]'"
  task :find, [ :week ] => :environment do |_, args|
    week = args[:week] ? Week.containing(Date.parse(args[:week])) : Week.last_complete
    finder = Themes::Finder.new
    themes = finder.call(week)
    abort "No embedded posts in #{week}. Run bin/rails 'ingest:backfill[2]' first." if themes.empty?

    usage = finder.last_response
    puts "#{week}: #{themes.size} themes (#{usage.input_tokens} in / #{usage.output_tokens} out tokens, ~$#{usage.cost_usd})"
    Rake::Task["themes:show"].invoke(week.to_param)
  end

  desc "Print a week's stored themes"
  task :show, [ :week ] => :environment do |_, args|
    week = args[:week] ? Week.containing(Date.parse(args[:week])) : Week.last_complete
    Theme.for_week(week).includes(:topics).each do |theme|
      puts "\n#{theme.position}. #{theme.label} [#{theme.kind}] #{theme.topic_count} threads, #{theme.post_count} posts, #{theme.author_count} people"
      puts "   #{theme.summary}"
      theme.topics.first(5).each { |topic| puts "   - #{topic.title}" }
    end
  end
end
