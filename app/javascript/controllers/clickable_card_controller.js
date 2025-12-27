import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (!this.urlValue) return
    if (event.defaultPrevented) return

    if (this.element.querySelector(".article-content")) return

    if (event.type === "keydown") {
      if (event.key !== "Enter" && event.key !== " ") return
    }

    const target = event.target
    const selection = window.getSelection?.()?.toString?.()
    if (selection && selection.length > 0) return

    if (target?.closest?.("a, button, input, textarea, select, label, summary, details")) return

    if (event.type === "keydown") {
      event.preventDefault()
    }

    const frame = this.element.querySelector("turbo-frame")
    if (frame) {
      frame.src = this.urlValue
      return
    }

    window.location.assign(this.urlValue)
  }
}
