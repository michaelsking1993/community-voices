import { Controller } from "@hotwired/stimulus"
import "plotly" // the vendored Plotly bundle sets window.Plotly

// Draws one Plotly figure. The server decides what to draw (see
// app/services/charts); this controller only hands the data to Plotly and
// matches the page's colours, so dark mode works.
export default class extends Controller {
  static values = { traces: Array, layout: Object }

  connect() {
    const style = getComputedStyle(document.body)
    const ink = style.color
    const line = style.getPropertyValue("--line").trim() || "#d2d2d7"
    const base = {
      paper_bgcolor: "rgba(0,0,0,0)", plot_bgcolor: "rgba(0,0,0,0)",
      font: { color: ink, family: style.fontFamily }, margin: { t: 20, r: 20, b: 60, l: 60 },
      xaxis: { gridcolor: line }, yaxis: { gridcolor: line }, legend: { orientation: "h", y: -0.2 }
    }
    const layout = this.#merge(base, this.layoutValue)
    window.Plotly.newPlot(this.element, this.tracesValue, layout, { responsive: true, displaylogo: false })
  }

  disconnect() { window.Plotly.purge(this.element) }

  #merge(base, extra) {
    const out = { ...base }
    for (const [key, value] of Object.entries(extra)) {
      const plain = value && typeof value === "object" && !Array.isArray(value)
      out[key] = plain ? { ...(base[key] || {}), ...value } : value
    }
    return out
  }
}
