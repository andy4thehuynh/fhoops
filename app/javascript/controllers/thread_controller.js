import { Controller } from "@hotwired/stimulus"

// Opens the conversation scrolled to the newest message, like Messages.
export default class extends Controller {
  connect() {
    window.scrollTo(0, document.body.scrollHeight)
  }
}
