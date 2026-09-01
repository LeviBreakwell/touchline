import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["total", "saveBtn", "capNotice"]
  // TRL's published try count for this fixture, or -1 while it is unpublished.
  static values = { official: { type: Number, default: -1 } }

  connect() {
    this.update()
  }

  // How many more of a field the roster can be credited with before it
  // overruns TRL. Infinite until TRL publishes a result.
  #remaining(field, excluding = 0) {
    if (this.officialValue < 0) return Infinity
    return this.officialValue - (this.#total(field) - excluding)
  }

  #total(field) {
    let sum = 0
    this.element.querySelectorAll(`input[data-field="${field}"]`).forEach(input => {
      sum += parseInt(input.value) || 0
    })
    return sum
  }

  inc(event) { this.#adjust(event.currentTarget, +1) }
  dec(event) { this.#adjust(event.currentTarget, -1) }

  togglePlayed(event) {
    const row = event.currentTarget.closest(".stat-row")
    if (!event.currentTarget.checked) this.#clear(row)
    this.update()
    this.#markDirty()
  }

  update() {
    let totalTries = 0, totalAssists = 0, playedCount = 0

    this.element.querySelectorAll(".stat-row").forEach(row => {
      const triesInput   = row.querySelector('input[data-field="tries"]')
      const assistsInput = row.querySelector('input[data-field="assists"]')
      const ptsEl        = row.querySelector("[data-pts]")
      const playedInput  = this.#playedInput(row)

      const tries   = parseInt(triesInput?.value)   || 0
      const assists = parseInt(assistsInput?.value) || 0

      if (playedInput) {
        row.classList.toggle("stat-row--out", !playedInput.checked)
        if (playedInput.checked) playedCount++
      }

      if (ptsEl) ptsEl.textContent = (tries * 2 + assists) + " pts"
      totalTries   += tries
      totalAssists += assists
    })

    if (this.hasTotalTarget) {
      const pts = totalTries * 2 + totalAssists
      const cap = this.officialValue < 0 ? "" : `/${this.officialValue}`
      this.totalTarget.textContent =
        `${playedCount} played · ${totalTries}${cap}T · ${totalAssists}${cap}A · ${pts} pts`
      this.totalTarget.classList.toggle(
        "stat-total-value--over",
        this.officialValue >= 0 && (totalTries > this.officialValue || totalAssists > this.officialValue)
      )
    }

    this.#markSpent("tries", totalTries)
    this.#markSpent("assists", totalAssists)
  }

  // Dim the + buttons for a field once TRL's number is fully spent, so the
  // ceiling reads before anyone presses into it.
  #markSpent(field, total) {
    const spent = this.officialValue >= 0 && total >= this.officialValue
    this.element
      .querySelectorAll(`.stepper-btn[data-field="${field}"][data-action*="inc"]`)
      .forEach(btn => btn.classList.toggle("stepper-btn--spent", spent))
  }

  // Refusing an increment: the button flashes, the stepper pushes back, and
  // the line explaining TRL's ceiling lights up so the reason is on screen.
  #refuse(btn) {
    this.#flash(btn, "flash-red")
    this.#pulse(btn.closest(".stepper"), "stepper--refused")
    if (this.hasCapNoticeTarget) this.#pulse(this.capNoticeTarget, "stat-hint--refused")
  }

  // Cleared on a timer rather than animationend, so the cue still clears for
  // anyone who has animations turned down.
  #pulse(el, cls) {
    if (!el) return
    el.classList.remove(cls)
    void el.offsetWidth
    el.classList.add(cls)
    clearTimeout(el.dataset.pulseTimer)
    el.dataset.pulseTimer = setTimeout(() => el.classList.remove(cls), 600)
  }

  #adjust(btn, delta) {
    const row     = btn.closest(".stat-row")
    const field   = btn.dataset.field
    const input   = row.querySelector(`input[data-field="${field}"]`)
    const display = row.querySelector(`[data-display="${field}"]`)

    const current = parseInt(input.value) || 0
    // A try TRL has no record of cannot be handed to anyone, so the stepper
    // stops at the team's remaining allowance rather than letting the save
    // fail. #remaining is already the most this row may hold, so it caps the
    // new value outright. A sheet that is somehow over the ceiling can still
    // come down — the ceiling never drags a value below where it sits.
    const ceiling = Math.max(current, Math.min(99, this.#remaining(field, current)))
    const next = delta > 0
      ? Math.min(current + delta, ceiling)
      : Math.max(0, current + delta)
    input.value = next
    if (display) display.textContent = next

    // Scoring is proof of an appearance, so recording one ticks the player on.
    const playedInput = this.#playedInput(row)
    if (next > 0 && playedInput) playedInput.checked = true

    // A stepper that refuses to move because TRL's number is spent still owes
    // the Member an answer, so it pushes back rather than doing nothing.
    if (next !== current) this.#flash(btn, delta > 0 ? "flash-green" : "flash-red")
    else if (delta > 0) this.#refuse(btn)

    this.update()
    this.#markDirty()
  }

  // A player marked absent carries no stats.
  #clear(row) {
    row.querySelectorAll('input[data-field="tries"], input[data-field="assists"]').forEach(input => {
      input.value = 0
      const display = row.querySelector(`[data-display="${input.dataset.field}"]`)
      if (display) display.textContent = "0"
    })
  }

  #playedInput(row) {
    return row.querySelector('input[type="checkbox"][data-field="played"]')
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
