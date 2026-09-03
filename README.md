# Decision Queue

A small web app for a studio that gets more partner product requests than it can act on. Requests go in with a title, the partner organization, a problem statement, expected impact, and urgency. They land in one queue, sorted so the most pressing pending work is on top, with a count of where everything stands. Each request gets a decision: accept, defer, or decline, with a reason that stays on the record.

Stack: Rails 8.1 on Ruby 3.3, PostgreSQL 17, Tailwind, minitest.

Rails was the framework of choice because the ORM, migrations, validations, and test setup come built in, which seemed like the best fit for a short & scoped task like this one. 

## Run it

You need Docker with Compose v2 (Docker Desktop is fine). Nothing else is required.

### Initialize from a clean checkout and run the app

```bash
git clone https://github.com/jwalcutt/decision-queue.git
cd decision-queue
docker compose up
```

The first run builds the image, which takes a few minutes. The web container then waits for PostgreSQL to report healthy, creates the development and test databases, runs the migrations, seeds the database with sample requests, and serves the app at [http://localhost:3000](http://localhost:3000). Later runs skip the build and keep your data.

Compose builds from `Dockerfile.dev`. The `Dockerfile` next to it is the Rails-generated production image and isn't used here.

### Run the tests

```bash
docker compose run --rm web bin/rails test
```

Works whether or not the app is running. Tests use their own database, so they never touch what you see in the browser.

### Reset local data

```bash
docker compose down -v
docker compose up
```

This drops the database volume and rebuilds a freshly seeded database. If you only want the sample data back without dropping anything:

```bash
docker compose run --rm web bin/rails db:seed
```

Seeding is idempotent: it skips requests that already exist, so running it twice doesn't duplicate rows.

### Other commands

```bash
docker compose run --rm web bin/rubocop
```

```bash
docker compose run --rm web bin/rails console
```

```bash
docker compose build
```

Rebuild after changing the Gemfile. Code and view changes are picked up live through the bind mount.

## Functional Requirements


| #   | Requirement                                                              | Where                                                                                                                                                                                                                                                                                                                                                                                                                         |
| --- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Create a request with title, problem statement, expected impact, urgency | "New request" on the queue, plus the partner organization. Missing fields re-render the form with a message per field. A request can be edited or deleted until its first decision.                                                                                                                                                                                                                                           |
| 2   | View all requests in a useful queue                                      | The root page. One row per request: title, organization, urgency and status as colour-coded badges, date. Pending first, then urgency high to low, then oldest first. Ten rows per page by default, with a rows-per-page control and page links that keep the active filters.                                                                                                                                                 |
| 3   | Filter or sort by status and urgency                                     | A Filters button opens a dialog with status, urgency, organization, and sort selects; active filters show as removable chips. Every column header has a toggle that cycles ascending, descending, off: Title and Organization alphabetically, Urgency high first, Status pending first, Submitted oldest first. Filters live in the URL, so a filtered view can be bookmarked. Each status count is also a link that filters. |
| 4   | Open a request and record accept, defer, or decline                      | Click a title. The request page shows the details, the decision history with full timestamps, and the decision form. Escape takes you back to the queue.                                                                                                                                                                                                                                                                      |
| 5   | Add a short reason                                                       | Required on every decision.                                                                                                                                                                                                                                                                                                                                                                                                   |
| 6   | See the current state of the queue                                       | Four counts above the table: pending, deferred, accepted, declined. They always cover the whole queue, even while a filter is active.                                                                                                                                                                                                                                                                                         |




## Non-functional requirements

- Runs locally with Docker Compose: a `web` container (Rails) and a `db` container (PostgreSQL 17). Not deployed anywhere.
- Data persists in PostgreSQL on a named volume.
- Schema is set up by Rails migrations, run automatically on every boot.
- Commands to initialize, run, test, and reset are above.
- Required input is validated at the model level with CHECK constraints behind it in the database. Errors name the field and say what to do: "Urgency can't be blank", "Decision is missing. Choose accept, defer, or decline."
- 83 automated tests. Integration tests cover the core loop end to end (create a request, find it in the queue, decide it, see the status and counts change), validation failures, the transition and edit rules, filters, sorts, pagination, and seed idempotency. Model tests cover the validations, ordering, the freeze after a decision, and the transaction around deciding.
- Sample data is fictional. Partner names are invented.



## How it works

Two tables: 

1. `requests` holds the request fields, the partner organization, and a status column (pending, accepted, deferred, declined).
2. `decisions` holds one row per decision: which request it belongs to, accepted/deferred/declined, the reason, and when. A request's status is a copy of its latest decision, kept on the row so the queue can filter and count without a join. The decisions table is the history.

Pending requests can be updated/deleted, while accepted and declined requests are final. Recording a decision inserts the decision row and updates the status inside one transaction with a row lock, so the two can't disagree. A request can be edited or deleted only while it is pending; once a decision exists, the text it was made against is frozen. The controller redirects away, and the model refuses the change too, so a console session hits the same rule.

Routes: the queue at `/`, the full `requests` resource, and `requests/:id/decisions` for create. A decision is created, not patched onto a request. Pagination is a sanitized `page` and `per_page` pair with `limit` and `offset`; out-of-range pages clamp to the last page, and unknown filter values are ignored rather than rejected, so a bad URL shows the nearest sensible view instead of an error.

The database credentials in `compose.yaml` are for the local containers only. There is no production configuration.

## Technical/Product Decisions

1. **Decisions use their own table, and status is copied onto the request.** The simpler model would have been having a `status` and a `reason` column in the request table itself. I opted to use a separate table instead because deferring a request could in theory happen multiple times for different reasons. This means that a request can carry more than one decision, and the reason for each should be documented.
2. **Used String enums with CHECK constraints instead of PostgreSQL enum types.** Native enum types need an `ALTER TYPE` migration to add a value and are awkward to read in `psql`, and integer enums make the raw data opaque. Strings with a CHECK constraint are readable in the database, and with Rails' `validate: true` a bad value becomes a form error rather than an exception.
3. **Added full CRUD functionality for pending requests, while keeping deferred, accepted, and declined requests read-only.** A decision is a judgment about a specific piece of text, so once one exists the request it refers to shouldn't change underneath it. Deferred requests can still be decided again, since deferring means "decide this later" and the history keeps both records, but accepted and declined decisions are final. The decisions table already contains what a "reopen" action would need, so relaxing this later is additive.

Some smaller calls:

- The `organization` column was added to the `requests` table. I made this change to allow requests from several partners to be validated, shown, or filtered on, which was not possible under the initial schema.
- Pagination is twenty lines of `limit` and `offset` with a sanitized page size, not a gem. It's small enough to read in one sitting and has no configuration to explain.
- `Esc` and `Enter` were added as keyboard shortcuts that can be used to navigate between views, submit requests, and clear filters.



## Known gaps

- Decisions cannot be undone. Accepted and declined are final, and there is no revert action. The fix would likely be a "reopened" decision type that sets the status back to pending while keeping the history intact, gated behind a reason like every other decision.
- Deferred requests have no revisit date or reminder. The fix is a date on the deferral, with overdue ones surfacing near the top of the queue.
- No searching functionality. The organization filter narrows the queue by partner, but there is no way to search titles or problem statements for example.
- No authentication layer. The app assumes one trusted person on localhost, so anything that involves multiple users would need this to be added.
- No browser-driven system tests. Integration tests exercise the controllers and rendered HTML, and the dialog / keyboard shortcuts were checked manually.



## Time spent

*Total: 4:59:44*