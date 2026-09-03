import { Controller } from "@hotwired/stimulus"

// Opens and closes the <dialog> it wraps. Clicking the backdrop or pressing
// Escape closes it. Wire it up with:
//   data-controller="dialog", a button with data-action="dialog#open", and
//   <dialog data-dialog-target="dialog"
//           data-action="click->dialog#closeOnBackdrop keydown.esc->dialog#close">
// Add data-dialog-open-value="true" to the controller element to open the
// dialog as soon as the page loads, e.g. to show a form that failed validation.
export default class extends Controller {
  static targets = [ "dialog" ]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.open()
  }

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
