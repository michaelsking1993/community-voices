# What a judge (an LLM, with checks in code) concluded about a report.
# One table for every kind, so the charts read one place:
#   prediction  a report's predictions scored against the following week (backtest)
#   support     does each cited sentence follow from the evidence it cites (A/B)
#   ranking     a blind comparison of one week's reports from every arm (A/B)
class CreateJudgements < ActiveRecord::Migration[8.1]
  def change
    create_table :judgements do |t|
      t.string :kind, null: false
      t.date :week_start, null: false
      t.references :report, foreign_key: { on_delete: :cascade } # null for a ranking across arms
      t.jsonb :data, null: false, default: {}
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :cost_usd, precision: 10, scale: 4
      t.integer :duration_ms
      t.timestamps
    end
    add_index :judgements, %i[kind week_start]
  end
end
