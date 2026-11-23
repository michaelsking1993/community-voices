# A forum thread's membership in a theme, with how close it sits to the
# theme's centre and how many of its posts fell in that week.
class ThemeTopic < ApplicationRecord
  belongs_to :theme
  belongs_to :topic
end
