require "rails_helper"

RSpec.describe "How I built it", type: :request do
  it "is the last tab" do
    get root_path

    tabs = response.body.scan(%r{<nav class="tabs".*?</nav>}m).first.scan(%r{<a [^>]*>([^<]+)</a>}).flatten
    expect(tabs.last).to eq("How I built it")
  end

  it "renders the README's How I built it section, read live from README.md" do
    get how_i_built_it_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{<a aria-current="page" href="/how-i-built-it">How I built it</a>})
    expect(response.body).to include("<h1>#{ERB::Util.html_escape(HowIBuiltItController::HEADING)}</h1>")

    # Every ### heading in that README section shows up on the page.
    readme = Rails.root.join("README.md").read
    section = readme[/^## #{Regexp.escape(HowIBuiltItController::HEADING)}\n(.*?)(?=^## )/m, 1]
    subheadings = section.scan(/^### (.+)$/).flatten
    expect(subheadings).not_to be_empty
    subheadings.each { |h| expect(response.body).to include(ERB::Util.html_escape(h)) }
  end
end
