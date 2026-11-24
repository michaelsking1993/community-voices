# One theme of one week: a cluster of forum threads, a model-written label
# and summary, and post/thread/author counts from SQL.
#
# Themes are our own idea, not the forum's: Topic and Post are Discourse's
# names for a thread and a message, while a theme is computed each week
# by Themes::Finder (k-means over thread vectors).
class Theme < ApplicationRecord
  KINDS = %w[problem request discussion announcement other].freeze

  has_many :theme_topics, -> { order(similarity: :desc) }, dependent: :delete_all
  has_many :topics, through: :theme_topics
  has_neighbors :centroid, dimensions: Embeddings::LocalModel::DIMENSIONS

  validates :kind, inclusion: { in: KINDS }

  scope :for_week, ->(week) { where(week_start: week.start).order(:position) }

  def week = Week.new(start: week_start)
end
