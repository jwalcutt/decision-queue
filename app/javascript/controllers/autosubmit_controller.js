import { Controller } from "@hotwired/stimulus"

// Submits the form it is attached to when a field changes. Wire it up with:
//   <form data-controller="autosubmit"> and data-action="change->autosubmit#submit" on a field.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
