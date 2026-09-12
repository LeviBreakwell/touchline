import { Controller } from "@hotwired/stimulus"

// A scope dropdown navigates on choice — there is no Go button, because there
// is nothing to do with the choice except follow it.
export default class extends Controller {
  go(event) {
    const url = event.target.value
    if (url) window.location.href = url
  }
}
