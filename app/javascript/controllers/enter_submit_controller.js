import { Controller } from "@hotwired/stimulus"

// Submits the form it's attached to when Enter is pressed in any field,
// including <select>s, which browsers don't submit on their own. Inside a
// textarea plain Enter still adds a newline; Cmd/Ctrl+Enter submits. Buttons
// and links keep their own Enter behaviour. Wire it up with:
//   data-controller="enter-submit" data-action="keydown->enter-submit#submit"
export default class extends Controller {
  submit(event) {
    if (event.key !== "Enter") return
    if (event.target.matches("button, a, input[type=submit]")) return
    if (event.target.matches("textarea") && !(event.metaKey || event.ctrlKey)) return

    event.preventDefault()
    this.element.requestSubmit()
  }
}
