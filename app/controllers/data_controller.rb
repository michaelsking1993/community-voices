# The Data tab: what has been crawled, and a button to crawl more.
class DataController < ApplicationController
  def show
    @status = Ingest::Status.new
    @last_crawl = JobRun.where(kind: "ingest").latest_first.first
  end
end
