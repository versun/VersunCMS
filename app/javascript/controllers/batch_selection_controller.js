import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-selection"
export default class extends Controller {
    static targets = ["checkbox", "selectAll", "actions", "count"]

    connect() {
        this.updateUI()
    }

    toggleAll(event) {
        const checked = event.target.checked
        this.checkboxTargets.forEach(checkbox => {
            checkbox.checked = checked
        })
        this.updateUI()
    }

    toggle() {
        this.updateUI()
    }

    updateUI() {
        const checkedBoxes = this.checkboxTargets.filter(cb => cb.checked)
        const hasSelection = checkedBoxes.length > 0

        // Show/hide batch actions
        if (this.hasActionsTarget) {
            this.actionsTarget.style.display = hasSelection ? 'flex' : 'none'
        }

        // Update select all checkbox state
        if (this.hasSelectAllTarget) {
            const allChecked = this.checkboxTargets.length > 0 &&
                checkedBoxes.length === this.checkboxTargets.length
            this.selectAllTarget.checked = allChecked
            this.selectAllTarget.indeterminate = checkedBoxes.length > 0 && !allChecked
        }

        // Update count display
        if (this.hasCountTarget) {
            this.countTarget.textContent = checkedBoxes.length
        }
    }

    getSelectedIds() {
        return this.checkboxTargets
            .filter(cb => cb.checked)
            .map(cb => cb.value)
    }

    submitBatchAction(event) {
        const selectedIds = this.getSelectedIds()

        if (selectedIds.length === 0) {
            event.preventDefault()
            alert('Please select at least one item.')
            return false
        }

        // Confirmation for destructive actions
        const action = event.target.dataset.action
        if (action && action.includes('delete') || action.includes('destroy')) {
            if (!confirm(`Are you sure you want to delete ${selectedIds.length} item(s)?`)) {
                event.preventDefault()
                return false
            }
        }

        return true
    }
}
