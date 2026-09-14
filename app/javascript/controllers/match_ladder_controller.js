import { Controller } from "@hotwired/stimulus"

// The gestures behind the match ladder.
//
//   tap                a try
//   drag card → card   that pass for that try: an assist for the source, a try
//                      for the target, in one row
//   hold 400ms         the Play menu — slide onto an item and release to pick.
//                      Below the usual items, whatever that card already has
//                      this game shows up as Remove — for the tap or drag that
//                      landed on the wrong person.
//   tap a sidelined card   brings them back on
//
// Every gesture writes one row and the server answers with the whole ladder,
// so the screen never has its own idea of the standing. The 400ms hold and the
// 340ms reorder were both settled by hand on a phone, not chosen on paper.
const REORDER_MS = 340
const FLASH_MS = 840
const DRAG_THRESHOLD = 12

const PLAY_KINDS = [
  { kind: "bomb_catch", label: "Bomb catch", value: "+1", sign: "plus" },
  { kind: "dropped_bomb", label: "Dropped bomb", value: "−1", sign: "minus" },
  { kind: "critical_error", label: "Critical error", value: "−8", sign: "minus" }
]

// The Remove section of that same menu: undoing something entered by mistake
// that isn't the last thing on the ladder any more. Each is only offered when
// the card carries at least one of that kind — count comes off the card's own
// data attributes, not a fetch — and removes the most recent one, since one
// occurrence of a kind is as good as any other to take back.
const REMOVALS = [
  { what: "try", data: "tries", label: "Remove a try" },
  { what: "assist", data: "assists", label: "Remove an assist" },
  { what: "bomb_catch", data: "bombCatches", label: "Remove a bomb catch" },
  { what: "dropped_bomb", data: "droppedBombs", label: "Remove a dropped bomb" },
  { what: "critical_error", data: "criticalErrors", label: "Remove a critical error" }
]

export default class extends Controller {
  static targets = ["board", "gutter", "dragLayer", "dragChip", "toast", "undo"]
  static values = { urls: Object, hold: { type: Number, default: 400 } }

  connect() {
    this.undoStack = []
    this.gesture = null
    this.onDown = this.#down.bind(this)
    this.onMove = this.#move.bind(this)
    this.onUp = this.#up.bind(this)
    this.onCancel = this.#cancel.bind(this)

    this.element.addEventListener("pointerdown", this.onDown)
    this.element.addEventListener("pointermove", this.onMove)
    this.element.addEventListener("pointerup", this.onUp)
    this.element.addEventListener("pointercancel", this.onCancel)

    this.#drawGutter()
    this.redraw = () => this.#drawGutter()
    window.addEventListener("resize", this.redraw)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onDown)
    this.element.removeEventListener("pointermove", this.onMove)
    this.element.removeEventListener("pointerup", this.onUp)
    this.element.removeEventListener("pointercancel", this.onCancel)
    window.removeEventListener("resize", this.redraw)
    this.#closeMenu()
  }

  // ── gestures ───────────────────────────────────────────────────────────
  #down(event) {
    const card = event.target.closest("[data-player-id]")
    if (!card) return
    event.preventDefault()

    this.gesture = {
      id: Number(card.dataset.playerId),
      name: card.dataset.playerName,
      sidelined: card.dataset.sidelined === "true",
      card,
      x0: event.clientX, y0: event.clientY,
      x: event.clientX, y: event.clientY,
      moved: false, held: false
    }
    card.setPointerCapture?.(event.pointerId)
    this.#startRing(card)

    this.gesture.timer = setTimeout(() => {
      if (!this.gesture || this.gesture.moved) return
      this.gesture.held = true
      this.gesture.hx = this.gesture.x
      this.gesture.hy = this.gesture.y
      this.gesture.menuMoved = false
      this.#clearRing()
      this.#openMenu(this.gesture)
      navigator.vibrate?.(12)
    }, this.holdValue)
  }

  #move(event) {
    const g = this.gesture
    if (!g) return
    g.x = event.clientX
    g.y = event.clientY

    // menu open, finger still down — slide onto an item
    if (g.held) {
      if (Math.hypot(event.clientX - g.hx, event.clientY - g.hy) > 8) g.menuMoved = true
      if (g.menuMoved) this.#hotMenuItem(event)
      return
    }

    if (Math.hypot(event.clientX - g.x0, event.clientY - g.y0) > DRAG_THRESHOLD) {
      if (!g.moved) {
        g.moved = true
        clearTimeout(g.timer)
        this.#clearRing()
        g.card.classList.add("armed")
      }
      this.#markTarget(event)
      this.#drawDragLine(g, event)
    }
  }

  #up(event) {
    const g = this.gesture
    if (!g) return
    clearTimeout(g.timer)
    this.#clearRing()
    this.#clearDragLine()
    g.card.classList.remove("armed")

    if (g.held) {
      // released over an item: that is the choice. Elsewhere: leave it open.
      const item = g.menuMoved ? this.#menuItemAt(event) : null
      this.gesture = null
      if (item) item.click()
      return
    }

    if (!g.moved) {
      this.gesture = null
      if (g.sidelined) this.#markPlayed(g.id)
      else this.#recordTry(g.id)
      return
    }

    const target = this.#playerAt(event)
    this.#clearTargets()
    this.gesture = null

    if (target && target !== g.id) this.#recordTry(target, g.id)
    else if (target === g.id) this.#toast("Dropped on themselves — nothing recorded")
    else this.#toast("Dropped on nothing — nothing recorded")
  }

  #cancel() {
    if (!this.gesture) return
    clearTimeout(this.gesture.timer)
    this.#clearRing()
    this.#clearTargets()
    this.#clearDragLine()
    this.gesture.card.classList.remove("armed")
    this.gesture = null
  }

  // ── writes ─────────────────────────────────────────────────────────────
  #recordTry(scorerId, assisterId = null) {
    const body = { scorer_player_id: scorerId }
    if (assisterId) body.assister_player_id = assisterId
    this.#write("POST", this.urlsValue.touchdowns, body, [ scorerId, assisterId ].filter(Boolean))
  }

  #recordPlay(playerId, kind) {
    this.#write("POST", this.urlsValue.plays, { player_id: playerId, kind }, [ playerId ])
  }

  #markPlayed(playerId) {
    this.#write("POST", this.urlsValue.appearances, { player_id: playerId }, [ playerId ])
  }

  #sideline(playerId) {
    this.#write("DELETE", `${this.urlsValue.appearances}/${playerId}`, null, [ playerId ])
  }

  // The hold menu's Remove items. "try" and "assist" are columns on a
  // Touchdown row rather than kinds of their own, so those two carry a role
  // instead of a kind — the server finds that player's most recent row in
  // that role and takes it, and the other column on that same row with it.
  #removeLatest(playerId, what) {
    const params = new URLSearchParams(
      what === "try" ? { player_id: playerId, role: "scorer" }
      : what === "assist" ? { player_id: playerId, role: "assister" }
      : { player_id: playerId, kind: what }
    )
    const base = (what === "try" || what === "assist") ? this.urlsValue.latestTouchdown : this.urlsValue.latestPlay
    this.#write("DELETE", `${base}?${params}`, null, [])
  }

  undo() {
    const last = this.undoStack.pop()
    if (!last) return this.#toast("Nothing to undo")
    this.#write("DELETE", last.path, null, [])
  }

  // One write at a time, in the order the gestures happened. Two taps a moment
  // apart must not land as two requests racing each other to answer.
  #write(method, url, body, flash) {
    this.chain = (this.chain ?? Promise.resolve()).then(() => this.#send(method, url, body, flash))
    return this.chain
  }

  async #send(method, url, body, flash) {
    let response
    try {
      response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content ?? ""
        },
        body: body ? JSON.stringify(body) : null
      })
    } catch {
      return this.#toast("Couldn't save that — check your connection")
    }

    if (!response.ok) {
      const message = await response.json().then(data => data.error).catch(() => null)
      return this.#toast(message ?? "Couldn't save that")
    }

    const data = await response.json()
    this.#swap(data.ladder, flash)
    if (data.undo) this.undoStack.push(data.undo)
    this.#refreshUndo()
    if (data.toast) this.#toast(data.toast)
  }

  // ── painting ───────────────────────────────────────────────────────────
  //
  // The ladder re-sorts as stats land, so a row that moves has to be seen
  // moving — otherwise the number under your thumb silently becomes somebody
  // else's. Measure before the swap, put every card back where it was, then
  // let it travel.
  #swap(html, flash) {
    const before = new Map()
    this.#cards().forEach(card => before.set(card.dataset.playerId, card.getBoundingClientRect().top))

    this.#reconcile(html)

    const travelled = this.#playReorder(before)
    this.#flash(flash)
    this.#drawGutter()
    if (travelled) {
      // the arcs are drawn at the destination, so hold them back until the
      // rows have got there
      this.gutterTarget.style.opacity = "0"
      setTimeout(() => { if (this.hasGutterTarget) this.gutterTarget.style.opacity = "1" }, REORDER_MS * 0.6)
    }
  }

  // The cards are reordered, not rebuilt. A card the finger is already on has to
  // survive the re-render — replacing the board wholesale drops a tap that
  // lands while the answer to the last one is arriving, which is exactly the
  // moment somebody entering a busy game is tapping again.
  #reconcile(html) {
    const incoming = document.createRange().createContextualFragment(html).firstElementChild
    const current = this.boardTarget.querySelector(".ladder")
    if (!incoming || !current) {
      this.boardTarget.innerHTML = html
      return
    }

    const kept = new Map(this.#cards().map(card => [ card.dataset.playerId, card ]))
    const order = Array.from(incoming.children).map(node => {
      const existing = node.classList?.contains("lcard") && kept.get(node.dataset.playerId)
      if (!existing) return node

      // The stat counts live in data attributes too — the Remove items in the
      // hold menu read them straight off the card — so every attribute is
      // brought over, not just the couple the old reconcile happened to name.
      for (const attr of node.attributes) existing.setAttribute(attr.name, attr.value)
      existing.innerHTML = node.innerHTML
      return existing
    })

    current.replaceChildren(...order)
  }

  #playReorder(before) {
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) return false

    let travelled = false
    this.#cards().forEach(card => {
      const was = before.get(card.dataset.playerId)
      if (was == null) return
      const dy = was - card.getBoundingClientRect().top
      if (Math.abs(dy) < 1) return

      travelled = true
      card.style.transition = "none"
      card.style.transform = `translateY(${dy}px)`
      requestAnimationFrame(() => {
        card.style.transition = `transform ${REORDER_MS}ms cubic-bezier(0.2,0.8,0.2,1)`
        card.style.transform = ""
      })
    })
    return travelled
  }

  #flash(ids) {
    ids.forEach(id => {
      const card = this.#card(id)
      card?.classList.add("just")
    })
    setTimeout(() => this.#cards().forEach(card => card.classList.remove("just")), FLASH_MS)
  }

  // One arc per pair who have connected, thickening the more often they do.
  // Anchored on offsetTop, which is a layout coordinate: unaffected by the
  // reorder animation's transforms, so an arc lands where the card is going
  // rather than where it is mid-flight.
  #drawGutter() {
    if (!this.hasGutterTarget) return
    const connections = JSON.parse(this.gutterTarget.dataset.connections || "[]")

    this.gutterTarget.innerHTML = connections.map(([ assister, scorer, count ]) => {
      const from = this.#card(assister), to = this.#card(scorer)
      if (!from || !to) return ""

      const y1 = from.offsetTop + from.offsetHeight / 2
      const y2 = to.offsetTop + to.offsetHeight / 2
      const x = 27
      const bulge = Math.min(23, 7 + Math.abs(y2 - y1) * 0.085)
      const width = Math.min(5, 1.3 + count)
      const opacity = Math.min(0.92, 0.34 + count * 0.17)

      return `<path d="M${x},${y1} C${x - bulge},${y1} ${x - bulge},${y2} ${x},${y2}"
                    fill="none" stroke="#58a6ff" stroke-width="${width}"
                    stroke-opacity="${opacity}" stroke-linecap="round"/>
              <circle cx="${x}" cy="${y1}" r="${width * 0.55 + 1}" fill="#58a6ff" fill-opacity="${opacity * 0.8}"/>
              <circle cx="${x}" cy="${y2}" r="${width * 0.75 + 1.8}" fill="#58a6ff" fill-opacity="${opacity}"/>`
    }).join("")
  }

  // ── the drag line ──────────────────────────────────────────────────────
  #drawDragLine(g, event) {
    const rect = g.card.querySelector(".lcard-avatar").getBoundingClientRect()
    const x1 = rect.left + rect.width / 2, y1 = rect.top + rect.height / 2
    const x2 = event.clientX, y2 = event.clientY

    const over = this.#playerAt(event)
    const valid = over && over !== g.id

    const dx = x2 - x1, dy = y2 - y1
    const length = Math.hypot(dx, dy) || 1
    const bow = Math.min(40, length * 0.16)
    const cx = (x1 + x2) / 2 - (dy / length) * bow
    const cy = (y1 + y2) / 2 + (dx / length) * bow
    const colour = valid ? "#58a6ff" : "#8b949e"

    this.dragLayerTarget.innerHTML =
      `<path d="M${x1},${y1} Q${cx},${cy} ${x2},${y2}" fill="none" stroke="${colour}"
             stroke-width="${valid ? 4 : 2.5}" stroke-linecap="round"
             stroke-opacity="${valid ? 0.95 : 0.5}" ${valid ? "" : 'stroke-dasharray="7 7"'}/>
       <circle cx="${x1}" cy="${y1}" r="5" fill="${colour}"/>
       ${valid ? `<circle cx="${x2}" cy="${y2}" r="9" fill="none" stroke="#58a6ff" stroke-width="3"/>` : ""}`

    if (valid) {
      const target = this.#card(over)
      this.dragChipTarget.innerHTML =
        `<span>${this.#firstName(g.name)} → ${this.#firstName(target.dataset.playerName)}</span>
         <span class="val">assist <b>+4</b> · try <i>+8</i></span>`
      // clear of the thumb, and clear of the screen edge
      const half = 84
      this.dragChipTarget.style.left = `${Math.max(half + 8, Math.min(window.innerWidth - half - 8, x2))}px`
      this.dragChipTarget.style.top = `${Math.max(8, y2 - 58)}px`
      this.dragChipTarget.style.transform = "translateX(-50%)"
      this.dragChipTarget.classList.add("on")
    } else {
      this.dragChipTarget.classList.remove("on")
    }
  }

  #clearDragLine() {
    this.dragLayerTarget.innerHTML = ""
    this.dragChipTarget.classList.remove("on")
  }

  // ── the hold ring ──────────────────────────────────────────────────────
  #startRing(card) {
    const avatar = card.querySelector(".lcard-avatar")
    if (!avatar) return

    // The fill is a CSS animation, so it starts with the element and there is
    // nothing here to kick off a frame later. The hold time is the only thing
    // the stylesheet cannot know.
    const ring = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    ring.setAttribute("class", "hold-ring")
    ring.setAttribute("viewBox", "0 0 56 56")
    ring.style.setProperty("--hold-ms", `${this.holdValue}ms`)

    const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    circle.setAttribute("cx", "28")
    circle.setAttribute("cy", "28")
    circle.setAttribute("r", "26")

    ring.appendChild(circle)
    avatar.appendChild(ring)
    this.gesture.ring = ring
  }

  #clearRing() {
    this.gesture?.ring?.remove()
    if (this.gesture) this.gesture.ring = null
  }

  // ── the Play menu ──────────────────────────────────────────────────────
  #openMenu(g) {
    this.#closeMenu()

    const removals = REMOVALS.filter(r => Number(g.card.dataset[r.data] || 0) > 0)

    const menu = document.createElement("div")
    menu.className = "play-menu"
    menu.innerHTML =
      `<div class="play-menu-head">${g.name}</div>` +
      PLAY_KINDS.map(k => `<button type="button" data-kind="${k.kind}">${k.label}<span class="v ${k.sign}">${k.value}</span></button>`).join("") +
      `<button type="button" data-kind="__sideline">${g.sidelined ? "Mark as played" : "Didn't play"}<span class="v mute">—</span></button>` +
      (removals.length
        ? `<div class="play-menu-div"></div>` +
          removals.map(r => `<button type="button" class="destructive" data-remove="${r.what}">${r.label}<span class="v mute">${g.card.dataset[r.data]}</span></button>`).join("")
        : "")
    document.body.appendChild(menu)

    // Capped before it is measured, so a menu with every Remove item showing
    // never claims more height than the screen has — it scrolls instead of
    // running off the bottom, on a phone in one hand as much as anywhere else.
    menu.style.maxHeight = `${window.innerHeight - 16}px`

    const width = 214, height = menu.offsetHeight
    menu.style.left = `${Math.max(8, Math.min(window.innerWidth - width - 8, g.x - width / 2))}px`
    menu.style.top = `${Math.max(8, Math.min(window.innerHeight - height - 8, g.y - height - 16))}px`

    menu.addEventListener("pointerdown", event => event.stopPropagation())
    menu.addEventListener("click", event => {
      const button = event.target.closest("button")
      if (!button) return
      const kind = button.dataset.kind
      const remove = button.dataset.remove
      if (kind === "__sideline") g.sidelined ? this.#markPlayed(g.id) : this.#sideline(g.id)
      else if (kind) this.#recordPlay(g.id, kind)
      else if (remove) this.#removeLatest(g.id, remove)
      this.#closeMenu()
    })

    setTimeout(() => document.addEventListener("pointerdown", () => this.#closeMenu(), { once: true }), 0)
    this.menu = menu
  }

  #closeMenu() {
    this.menu?.remove()
    this.menu = null
  }

  #menuItemAt(event) {
    if (!this.menu) return null
    const element = document.elementFromPoint(event.clientX, event.clientY)
    if (!element || !this.menu.contains(element)) return null
    return element.closest("button")
  }

  #hotMenuItem(event) {
    if (!this.menu) return
    const hot = this.#menuItemAt(event)
    this.menu.querySelectorAll("button").forEach(button => button.classList.toggle("hot", button === hot))
  }

  // ── helpers ────────────────────────────────────────────────────────────
  #cards() { return Array.from(this.element.querySelectorAll(".lcard[data-player-id]")) }
  #card(id) { return this.element.querySelector(`.lcard[data-player-id="${id}"]`) }

  #playerAt(event) {
    const element = document.elementFromPoint(event.clientX, event.clientY)
    const card = element?.closest?.("[data-player-id]")
    return card ? Number(card.dataset.playerId) : null
  }

  #markTarget(event) {
    this.#clearTargets()
    const id = this.#playerAt(event)
    if (id && this.gesture && id !== this.gesture.id) this.#card(id)?.classList.add("target")
  }

  #clearTargets() {
    this.element.querySelectorAll(".target").forEach(card => card.classList.remove("target"))
  }

  #refreshUndo() {
    if (this.hasUndoTarget) this.undoTarget.hidden = this.undoStack.length === 0
  }

  #firstName(name) { return name.split(" ")[0] }

  #toast(message) {
    if (!this.hasToastTarget) return
    this.toastTarget.textContent = message
    this.toastTarget.classList.add("show")
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.toastTarget.classList.remove("show"), 1600)
  }
}
