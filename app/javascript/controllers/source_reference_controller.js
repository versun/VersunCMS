import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "archiveUrl", "archiveBtn", "fetchBtn", "author", "content", "status"]

  connect() {
    // Controller initialized
  }

  async fetchTwitter(event) {
    event.preventDefault()
    event.stopPropagation()

    const url = this.urlTarget.value.trim()

    if (!url) {
      this.showStatus("Please enter a Source URL first", "error")
      return
    }

    // Check if it's a Twitter/X URL
    if (!this.isTwitterUrl(url)) {
      this.showStatus("Not a Twitter/X URL", "error")
      return
    }

    this.setLoading(this.fetchBtnTarget, true)
    this.showStatus("Fetching tweet content...", "info")

    try {
      const response = await fetch("/admin/sources/fetch_twitter", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ url: url })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        if (this.hasAuthorTarget && data.author) {
          this.authorTarget.value = data.author
        }
        if (this.hasContentTarget && data.content) {
          this.contentTarget.value = data.content
        }
        this.showStatus("Tweet content fetched!", "success")
      } else {
        this.showStatus(data.error || "Failed to fetch tweet", "error")
      }
    } catch (error) {
      console.error("Fetch error:", error)
      this.showStatus(`Network error: ${error.message}`, "error")
    } finally {
      this.setLoading(this.fetchBtnTarget, false)
    }
  }

  isTwitterUrl(url) {
    try {
      const uri = new URL(url)
      const host = uri.hostname.toLowerCase()
      return ["twitter.com", "www.twitter.com", "x.com", "www.x.com"].includes(host)
    } catch (e) {
      return false
    }
  }

  async archiveUrl(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const url = this.urlTarget.value.trim()
    
    if (!url) {
      this.showStatus("Please enter a Source URL first", "error")
      return
    }

    // 验证 URL 格式
    try {
      new URL(url)
    } catch (e) {
      this.showStatus("Invalid URL format", "error")
      return
    }

    this.setLoading(this.archiveBtnTarget, true)
    this.showStatus("Saving to Internet Archive... (this may take a moment)", "info")

    try {
      const response = await fetch("/admin/sources/archive", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ url: url })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.archiveUrlTarget.value = data.archived_url
        this.showStatus("URL archived successfully!", "success")
      } else {
        this.showStatus(data.error || "Failed to archive URL", "error")
      }
    } catch (error) {
      console.error("Archive error:", error)
      this.showStatus(`Network error: ${error.message}`, "error")
    } finally {
      this.setLoading(this.archiveBtnTarget, false)
    }
  }

  setLoading(button, loading) {
    if (loading) {
      button.disabled = true
      if (!button.dataset.originalText) {
        button.dataset.originalText = button.innerHTML
      }
      button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Loading...'
    } else {
      button.disabled = false
      if (button.dataset.originalText) {
        button.innerHTML = button.dataset.originalText
      }
    }
  }

  showStatus(message, type) {
    const statusEl = this.statusTarget
    statusEl.textContent = message
    statusEl.style.display = "block"
    
    // Set colors based on type
    switch (type) {
      case "success":
        statusEl.style.backgroundColor = "#d4edda"
        statusEl.style.color = "#155724"
        statusEl.style.border = "1px solid #c3e6cb"
        break
      case "error":
        statusEl.style.backgroundColor = "#f8d7da"
        statusEl.style.color = "#721c24"
        statusEl.style.border = "1px solid #f5c6cb"
        break
      case "info":
      default:
        statusEl.style.backgroundColor = "#d1ecf1"
        statusEl.style.color = "#0c5460"
        statusEl.style.border = "1px solid #bee5eb"
        break
    }

    // Auto-hide success messages after 5 seconds
    if (type === "success") {
      setTimeout(() => {
        statusEl.style.display = "none"
      }, 5000)
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
