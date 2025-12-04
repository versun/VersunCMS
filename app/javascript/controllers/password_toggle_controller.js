import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "toggleButton"]

  connect() {
    this.updateToggleButton()
  }

  toggle() {
    const input = this.inputTarget
    const type = input.getAttribute("type")
    
    if (type === "password") {
      input.setAttribute("type", "text")
      this.toggleButtonTarget.textContent = "Hide"
      this.toggleButtonTarget.setAttribute("aria-label", "隐藏密码")
    } else {
      input.setAttribute("type", "password")
      this.toggleButtonTarget.textContent = "Show"
      this.toggleButtonTarget.setAttribute("aria-label", "显示密码")
    }
  }

  updateToggleButton() {
    if (this.hasToggleButtonTarget) {
      const input = this.inputTarget
      const type = input.getAttribute("type")
      if (type === "password") {
        this.toggleButtonTarget.textContent = "Show"
        this.toggleButtonTarget.setAttribute("aria-label", "显示密码")
      } else {
        this.toggleButtonTarget.textContent = "Hide"
        this.toggleButtonTarget.setAttribute("aria-label", "隐藏密码")
      }
    }
  }
}

