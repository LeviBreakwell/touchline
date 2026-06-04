import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["total", "saveBtn"]

  connect() {
    this.update()
  }

  inc(event) { this.#adjust(event.currentTarget, +1) }
  dec(event) { this.#adjust(event.currentTarget, -1) }

  update() {
    let totalTries = 0, totalAssists = 0

    this.element.querySelectorAll(".stat-row").forEach(row => {
      const triesInput   = row.querySelector('input[data-field="tries"]')
      const assistsInput = row.querySelector('input[data-field="assists"]')
      const ptsEl        = row.querySelector("[data-pts]")

      const tries   = parseInt(triesInput?.value)   || 0
      const assists = parseInt(assistsInput?.value) || 0

      if (ptsEl) ptsEl.textContent = (tries * 2 + assists) + " pts"
      totalTries   += tries
      totalAssists += assists
    })

    if (this.hasTotalTarget) {
      const pts = totalTries * 2 + totalAssists
      this.totalTarget.textContent = `${totalTries}T · ${totalAssists}A · ${pts} pts`
    }
  }

  #adjust(btn, delta) {
    const row     = btn.closest(".stat-row")
    const field   = btn.dataset.field
    const input   = row.querySelector(`input[data-field="${field}"]`)
    const display = row.querySelector(`[data-display="${field}"]`)

    const current = parseInt(input.value) || 0
    const next = Math.max(0, Math.min(99, current + delta))
    input.value = next
    if (display) display.textContent = next

    if (next !== current) this.#flash(btn, delta > 0 ? "flash-green" : "flash-red")

    this.update()
    this.#markDirty()
  }

  #flash(btn, cls) {
    btn.classList.remove("flash-green", "flash-red")
    void btn.offsetWidth
    btn.classList.add(cls)
    btn.addEventListener("animationend", () => btn.classList.remove(cls), { once: true })
  }

  #markDirty() {
    if (!this.hasSaveBtnTarget) return
    const btn = this.saveBtnTarget
    btn.textContent = "Save changes"
    btn.classList.remove("btn-secondary")
    btn.classList.add("btn-primary")
  }
}
