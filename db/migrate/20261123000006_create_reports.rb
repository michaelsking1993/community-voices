# A generated Community Voices report. It is an output, never a source:
# nothing here is chunked or embedded, so the model never retrieves its
# own writing. `arm` lets the A/B step store several versions of one week.
class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.date :week_start, null: false
      t.string :arm, null: false, default: "rag"
      t.string :status, null: false, default: "pending"
      t.jsonb :content, null: false, default: {}   # the model's structured answer
      t.jsonb :evidence, null: false, default: {}  # E-number => chunk, post, url, title, date, text
      t.jsonb :grounding, null: false, default: {} # citation and quote checks, done by code
      t.text :markdown
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :cost_usd, precision: 10, scale: 4
      t.integer :duration_ms
      t.text :error
      t.timestamps
    end
    add_index :reports, [ :week_start, :arm, :created_at ]

    add_reference :retrievals, :report, foreign_key: { on_delete: :nullify }
  end
end
