import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "productSelector"]

  add() {
    this.containerTarget.insertAdjacentHTML("beforeend", this.newRowHtml())
  }

  addFromProduct() {
    const productId = this.productSelectorTarget.value
    if (!productId) return

    fetch(`/products/${productId}.json`)
      .then((response) => response.json())
      .then((data) => {
        const row = this.appendNewRow()
        this.fillRow(row, data)
        this.productSelectorTarget.value = ""
      })
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

  newRowHtml() {
    return this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
  }

  appendNewRow() {
    this.containerTarget.insertAdjacentHTML("beforeend", this.newRowHtml())
    return this.containerTarget.lastElementChild
  }

  fillRow(row, data) {
    row.querySelector("[data-line-item-fill='description']").value = data.description || data.name
    row.querySelector("[data-line-item-fill='quantity']").value = 1
    row.querySelector("[data-line-item-fill='unitCode']").value = data.unit_code
    row.querySelector("[data-line-item-fill='unitLabel']").textContent = data.unit_code_label
    row.querySelector("[data-line-item-fill='unitPrice']").value = data.default_price
    row.querySelector("[data-line-item-fill='taxCategory']").value = data.tax_category_code
    row.querySelector("[data-line-item-fill='vatRate']").value = data.default_vat_rate
    row.querySelector("[data-line-item-fill='vatLabel']").textContent = data.vat_label
  }
}
