# A Monday-to-Monday window, the unit everything is reported in. Matches
# Postgres's date_trunc('week', ...), which also starts weeks on Monday.
#
# Pass a different `today` to pretend it is an earlier date: that is how
# the prediction backtest generates "next week" using only older data.
Week = Data.define(:start) do
  def self.containing(time) = new(start: time.to_date.beginning_of_week(:monday))
  def self.last_complete(today = Time.zone.today) = containing(today).previous

  def finish = start + 7
  def range = start.in_time_zone...finish.in_time_zone
  def previous(weeks = 1) = with(start: start - (7 * weeks))
  def next = with(start: finish)
  def to_s = "#{start.iso8601} to #{(finish - 1).iso8601}"
  def to_param = start.iso8601
end
