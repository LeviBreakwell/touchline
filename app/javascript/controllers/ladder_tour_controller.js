import { Controller } from "@hotwired/stimulus"

// The stat-entry tour: shown once per browser, then only on request via the
// "?" button. Composes with the generic "dialog" controller for backdrop and
// close-button behaviour — this one only decides *when* to open on its own
// and remembers that it has. Listening for the dialog's own "close" event
// (rather than wiring every close path by hand) means Esc, the backdrop and
// the close button all count as having seen it.
const SEEN_KEY = "touchline:seen-ladder-tour"

export default class extends Controller {
  static targets = [ "dialog" ]

  connect() {
    if (!this.#seen()) this.dialogTarget.showModal()
  }

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
  }

  dismiss() {
    this.#markSeen()
  }

  #seen() {
    try { return localStorage.getItem(SEEN_KEY) === "1" } catch { return true }
  }

  #markSeen() {
    try { localStorage.setItem(SEEN_KEY, "1") } catch { /* private browsing, etc. */ }
  }
}
