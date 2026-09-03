import { Controller } from "@hotwired/stimulus"

// Fades out and removes the flash message it's attached to after a few
// seconds. Wire it up with data-controller="flash"; override the wait with
// data-flash-delay-value (milliseconds).
export default class extends Controller {
  static values = { delay: { type: Number, default: 4000 } }
  static FADE_MS = 500

  connect() {
    this.element.classList.add("transition-opacity", "duration-500")
    this.timer = setTimeout(() => this.fade(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  fade() {
    // A timer rather than transitionend: hidden tabs and reduced-motion
    // settings skip the transition, and the message must still go away.
    this.element.classList.add("opacity-0")
    this.timer = setTimeout(() => this.element.remove(), this.constructor.FADE_MS)
  }
}
