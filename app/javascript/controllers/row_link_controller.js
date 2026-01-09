import { Controller } from "@hotwired/stimulus"

// Makes an element (e.g., table row) behave like a link
// Usage:
// data-controller="row-link"
// data-row-link-href-value="/path"
// data-action="click->row-link#navigate keydown->row-link#navigateByKey"
export default class extends Controller {
  static values = { href: String }

  navigate(event) {
    // Ignore clicks on interactive elements inside the row
    if (event.target.closest("a, button, input, textarea, select, label, summary")) return
    if (!this.hasHrefValue) return
    window.location.assign(this.hrefValue)
  }

  navigateByKey(event) {
    if (!this.hasHrefValue) return
    // Activate on Enter or Space when the row has focus
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      window.location.assign(this.hrefValue)
    }
  }
}


