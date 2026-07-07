import { Controller } from "@hotwired/stimulus"

// Drag-to-reorder for the favorites strip. HTML5 drag and drop, then a
// PATCH with the new order of contact ids.
export default class extends Controller {
  static values = { url: String }

  dragstart(event) {
    this.dragged = event.target.closest("[data-contact-id]")
    this.dragged?.classList.add("dragging")
  }

  dragover(event) {
    event.preventDefault()
    const over = event.target.closest("[data-contact-id]")
    if (!this.dragged || !over || over === this.dragged) return

    const items = [...this.element.querySelectorAll("[data-contact-id]")]
    if (items.indexOf(this.dragged) < items.indexOf(over)) {
      over.after(this.dragged)
    } else {
      over.before(this.dragged)
    }
  }

  async dragend() {
    if (!this.dragged) return
    this.dragged.classList.remove("dragging")
    this.dragged = null

    const contact_ids = [...this.element.querySelectorAll("[data-contact-id]")]
      .map((el) => el.dataset.contactId)

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ contact_ids })
    })
  }
}
