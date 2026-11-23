namespace :report do
  desc "Write the Community Voices report for a week (default: last complete week). Example: bin/rails 'report:build[2026-11-16]'"
  task :build, [ :week ] => :environment do |_, args|
    week = args[:week] ? Week.containing(Date.parse(args[:week])) : Week.last_complete
    puts "Writing the report for #{week}..."
    report = Reports::Builder.new.call(week)
    g = report.grounding
    puts report.markdown
    puts "---"
    puts "Report ##{report.id}: #{report.input_tokens} in / #{report.output_tokens} out tokens, ~$#{report.cost_usd}, #{report.duration_ms} ms"
    puts "Citations valid: #{g["citations_valid"]}/#{g["citations"]}. Quotes word for word: #{g["quotes_verbatim"]}/#{g["quotes"]}. " \
         "Uncited sentences: #{g["sentences_uncited"]}/#{g["sentences"]}."
  end
end
