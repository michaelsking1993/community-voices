import { Controller } from "@hotwired/stimulus"

// Shows one flashcard at a time. The server renders every card (hidden);
// this controller only decides which one is visible and whether it is flipped.
// `order` is a list of card positions, so Shuffle reorders the list without
// touching the page, and Reset puts it back in the original order.
export default class extends Controller {
  static targets = ["card", "back", "position", "bar"]

  connect() {
    this.order = this.cardTargets.map((_, i) => i)
    this.at = 0
    this.render()
  }

  flip() { this.flipped = !this.flipped; this.render() }
  next() { this.go(1) }
  previous() { this.go(-1) }
  go(step) {
    this.at = (this.at + step + this.order.length) % this.order.length
    this.flipped = false
    this.render()
  }

  shuffle() {
    // Fisher-Yates: walk backwards, swap each slot with a random earlier one
    for (let i = this.order.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[this.order[i], this.order[j]] = [this.order[j], this.order[i]]
    }
    this.at = 0
    this.flipped = false
    this.render()
  }

  reset() {
    this.order = this.cardTargets.map((_, i) => i)
    this.at = 0
    this.flipped = false
    this.render()
  }

  key(event) {
    if (event.target.closest("input, textarea")) return
    if (event.key === "ArrowRight") this.next()
    else if (event.key === "ArrowLeft") this.previous()
    else if (event.key === " " && event.target === document.body) { event.preventDefault(); this.flip() }
  }

  render() {
    const shown = this.order[this.at]
    this.cardTargets.forEach((card, i) => {
      card.hidden = i !== shown
      this.backTargets[i].hidden = !(i === shown && this.flipped)
    })
    this.positionTarget.textContent = `Card ${this.at + 1} of ${this.order.length}`
    this.barTarget.style.width = `${((this.at + 1) / this.order.length) * 100}%`
  }
}
