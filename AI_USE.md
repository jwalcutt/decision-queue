# AI use

## Tools used

### Claude Code

**Tasks the tool assisted:**

- Writing a short + concrete implementation plan for each high-level step in the backlog that I either approved or redirected.
- Drafting the implementation of approved plans.
- Writing the minitest suite alongside each feature.
- Running tests and rubocop in the containers.
- Checking pages in a browser and with curl.

The product and technical calls behind the code were made by me beforehand or during the build. They are listed in the README under "Technical/Product Decisions".

**Intermediate artifacts generated through AI use:**

- Generator output (Rails scaffold and model generators) that the tool then edited.
- The seeded data set: 56 fictional requests across eight invented partner organizations, all names and copy invented.
- The setup portion of `README.md`

**Important output checked or changed:**

- I read every diff before committing the output myself. Here are a few examples of things I caught and changed:
  1. A decision form that raised on a missing radio choice instead of showing a validation error.
  2. Seeds that broke when the terminal-state guard was added.
  3. A test that needed a stub library not loadable in this bundle. I then had the test rewritten without it.
  4. A filter chip being shown for the default sorting option.
  5. Page links that carried raw, unsanitized per-page values.



## Final review

- [x] I understand the important AI-assisted work in this repository.
- [x] I checked or changed important AI output before submission.
- [x] I did not include private or proprietary information in this file.