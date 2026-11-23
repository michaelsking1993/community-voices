module RecordHelpers
  def create_post(raw:, id: Post.maximum(:discourse_id).to_i + 1, topic: nil, posted_at: Time.zone.parse("2026-11-20 09:00"))
    topic ||= Topic.find_or_create_by!(discourse_id: 1) do |t|
      t.title = "Sync keeps failing"
      t.slug = "sync-keeps-failing"
      t.category_name = "Anki › Syncing & AnkiWeb"
    end
    Post.create!(topic:, discourse_id: id, post_number: id, username: "user#{id}", raw:, posted_at:)
  end

  def words(n, word = "review") = Array.new(n) { |i| "#{word}#{i}" }.join(" ")
end

RSpec.configure { |c| c.include RecordHelpers }
