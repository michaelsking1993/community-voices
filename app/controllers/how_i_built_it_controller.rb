# Shows README.md's "How I built it" section, read live from the file.
class HowIBuiltItController < ApplicationController
  HEADING = "How I built it: a learner's approach".freeze

  def show
    @section = Readme::Section.new.call(HEADING)
  end
end
