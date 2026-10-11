import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    if (event && this.element.contains(event.target)) return
    this.element.removeAttribute("open")
  }

  closeOnEscape(event) {
    if (event.key !== "Escape") return
    this.element.removeAttribute("open")
    this.element.querySelector("summary")?.focus()
  }
}
