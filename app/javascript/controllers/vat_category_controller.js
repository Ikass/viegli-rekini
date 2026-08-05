import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "rate"]

  updateRate() {
    const rateMap = {
      "S": 21,
      "S12": 12,
      "S5": 5,
      "Z": 0,
      "E": 0,
      "AE": 0,
      "G": 0
    }
    const code = this.categoryTarget.value
    if (code in rateMap) {
      this.rateTarget.value = rateMap[code]
    }
  }
}
