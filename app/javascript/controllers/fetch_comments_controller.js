import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fetch-comments"
export default class extends Controller {
    static targets = ["button", "icon"]
    static values = { platform: String }

    connect() {
        // Store original icon class for restoration
        if (this.hasIconTarget) {
            this.originalIconClass = this.iconTarget.className
        }
    }

    async submit(event) {
        event.preventDefault()
        event.stopPropagation()

        const form = this.element
        const button = this.buttonTarget
        const icon = this.hasIconTarget ? this.iconTarget : null
        const formData = new FormData(form)
        const url = form.action

        // Get CSRF token from meta tag (Rails standard)
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

        // Show loading state
        if (button) {
            button.disabled = true
        }
        if (icon) {
            if (!this.originalIconClass) {
                this.originalIconClass = icon.className
            }
            icon.className = 'fas fa-spinner fa-spin'
        }

        try {
            // Use fetch with Turbo-compatible headers
            const response = await fetch(url, {
                method: 'POST',
                body: formData,
                headers: {
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-CSRF-Token': csrfToken || ''
                },
                credentials: 'same-origin'
            })

            const data = await response.json()
            
            if (data.success) {
                alert(data.message)
                // Optional: Reload page to update comment count
                // window.Turbo?.visit(window.location.href)
            } else {
                alert(data.message || 'Failed to fetch comments')
            }
        } catch (error) {
            console.error('Error fetching comments:', error)
            alert('An error occurred while fetching comments.')
        } finally {
            // Restore button and icon state
            if (button) {
                button.disabled = false
            }
            if (icon && this.originalIconClass) {
                icon.className = this.originalIconClass
            }
        }
    }
}

