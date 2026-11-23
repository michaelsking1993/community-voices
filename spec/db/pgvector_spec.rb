require "rails_helper"

# Smoke test for the foundation everything else stands on: Postgres can
# store vectors and measure the distance between them.
RSpec.describe "pgvector" do
  def select_value(sql) = ActiveRecord::Base.connection.select_value(sql)

  it "is enabled in the database" do
    expect(select_value("SELECT extname FROM pg_extension WHERE extname = 'vector'")).to eq("vector")
  end

  it "computes cosine distance with the <=> operator" do
    same = select_value("SELECT '[1,0,0]'::vector <=> '[2,0,0]'::vector")
    orthogonal = select_value("SELECT '[1,0,0]'::vector <=> '[0,1,0]'::vector")

    expect(same).to be_within(1e-6).of(0.0)      # same direction, distance 0
    expect(orthogonal).to be_within(1e-6).of(1.0) # unrelated, distance 1
  end
end
