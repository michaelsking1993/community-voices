# Study cards for the vocabulary learned while building this project.
# The deck lives in config/flashcards.yml; no database or API key is involved.
class FlashcardsController < ApplicationController
  def show
    @cards = Rails.application.config_for(:flashcards).fetch(:cards) # see config/flashcards.yml
  end
end
