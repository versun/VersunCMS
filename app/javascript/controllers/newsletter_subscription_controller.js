import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "emailInput", "submitBtn", "message"]

  async submit(event) {
    event.preventDefault()

    const email = this.emailInputTarget.value.trim()
    
    if (!email) {
      this.showMessage("请输入有效的邮箱地址。", "error")
      return
    }

    // 验证邮箱格式
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(email)) {
      this.showMessage("请输入有效的邮箱地址。", "error")
      return
    }

    // 禁用提交按钮
    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.textContent = "提交中..."

    try {
      const formData = new FormData(this.formTarget)
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        },
        body: formData
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.showMessage(data.message || "订阅成功！请检查您的邮箱并点击确认链接。", "success")
        this.emailInputTarget.value = ""
      } else {
        this.showMessage(data.message || "订阅失败，请稍后重试。", "error")
      }
    } catch (error) {
      this.showMessage("网络错误，请稍后重试。", "error")
    } finally {
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.textContent = "订阅"
    }
  }

  showMessage(text, type) {
    const messageEl = this.messageTarget
    messageEl.textContent = text
    messageEl.className = `newsletter-message newsletter-message-${type}`
    messageEl.style.display = "block"

    // 如果是成功消息，3秒后淡出
    if (type === "success") {
      setTimeout(() => {
        messageEl.style.opacity = "0"
        setTimeout(() => {
          messageEl.style.display = "none"
          messageEl.style.opacity = "1"
        }, 300)
      }, 3000)
    }
  }
}
