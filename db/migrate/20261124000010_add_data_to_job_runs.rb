# Structured results next to the printed summary, so the Evaluate tab can
# draw a table instead of showing terminal text.
class AddDataToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :data, :jsonb
  end
end
