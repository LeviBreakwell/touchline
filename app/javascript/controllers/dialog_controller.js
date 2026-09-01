import { Controller } from "@hotwired/stimulus"

// Wraps a <dialog>. The trigger stays a real link to the standalone page, so
// the flow still works if this controller never loads.
export default class extends Controller {
  static targets = ["dialog", "firstField"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.#show()
  }

  open(event) {
    event.preventDefault()
    this.#show()
  }

  close() {
    this.dialogTarget.close()
  }

  // A click on the backdrop lands on the dialog element itself.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  #show() {
    this.dialogTarget.showModal()
    if (this.hasFirstFieldTarget) this.firstFieldTarget.focus()
  }
}
