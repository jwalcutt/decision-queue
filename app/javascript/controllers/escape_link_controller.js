import { Controller } from "@hotwired/stimulus"

// Follows the link this controller is attached to when Escape is pressed
// anywhere on the page. A keypress from inside a <dialog> is left alone, since
// Escape closes the dialog instead. Wire it up with:
//   data-controller="escape-link" data-action="keydown.esc@window->escape-link#follow"
export default class extends Controller {
  follow(event) {
    if (event.target.closest?.("dialog")) return

    event.preventDefault()
    this.element.click()
  }
}
