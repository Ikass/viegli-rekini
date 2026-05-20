import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container"]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()

    const wrapper = event.target.closest("[data-nested-form-field]")
    const destroyInput = wrapper.querySelector("input[name*='_destroy']")

    if (destroyInput) {
      // Persisted record — mark for destruction and hide.
      destroyInput.value = "1"
      wrapper.style.display = "none"
    } else {
      // New record — remove from DOM entirely.
      wrapper.remove()
    }
  }
}
