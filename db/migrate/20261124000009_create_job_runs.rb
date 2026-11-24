# One row per press of a button on the Evaluate tab (crawl, A/B test, backtest,
# retrieval eval): what was asked, whether it is still running, and what it
# printed. The rake tasks print the same text to the terminal.
class CreateJobRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :job_runs do |t|
      t.string :kind, null: false
      t.integer :weeks
      t.string :status, null: false, default: "queued"
      t.text :summary
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :job_runs, %i[kind created_at]
  end
end
