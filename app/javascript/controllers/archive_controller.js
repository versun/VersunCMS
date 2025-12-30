import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["verifyIaStatus"]

  async verifyIa(event) {
    event.preventDefault()

    const statusEl = this.verifyIaStatusTarget
    statusEl.innerHTML = '<span style="color: gray;">验证中...</span>'

    try {
      const response = await fetch('/admin/archives/verify_ia', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html'
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        statusEl.innerHTML = '<span style="color: red;">验证失败</span>'
      }
    } catch (error) {
      statusEl.innerHTML = `<span style="color: red;">错误: ${error.message}</span>`
    }
  }
}
