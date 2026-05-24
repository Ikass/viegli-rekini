import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selector", "description", "quantity", "unitPrice", "vatRate"]

  connect() {
    if (this.selectorTarget.value) {
      this.loadProduct(this.selectorTarget.value)
    }
  }

  select() {
    const productId = this.selectorTarget.value
    if (productId) {
      this.loadProduct(productId)
    }
  }

  loadProduct(id) {
    fetch(`/products/${id}.json`)
      .then(response => response.json())
      .then(data => {
        this.descriptionTarget.value = data.description || data.name
        this.quantityTarget.value = 1
        this.unitPriceTarget.value = data.default_price
        this.vatRateTarget.value = data.default_vat_rate
      })
  }
}
