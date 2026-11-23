module Charts
  # One Plotly figure as plain data: the page renders it with a Stimulus
  # controller (app/javascript/controllers/plot_controller.js), so no
  # chart logic lives in the browser.
  Chart = Data.define(:id, :title, :caption, :traces, :layout) do
    def self.build(id:, title:, caption:, traces:, layout: {}) = new(id:, title:, caption:, traces:, layout:)
  end
end
