import { Controller } from "@hotwired/stimulus"

// Opens and closes the <dialog> it wraps. Clicking the backdrop or pressing
// Escape closes it. Wire it up with:
//   data-controller="dialog", a button with data-action="dialog#open", and
//   <dialog data-dialog-target="dialog"
//           data-action="click->dialog#closeOnBackdrop keydown.esc->dialog#close">
export default class extends Controller {
  static targets = [ "dialog" ]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
