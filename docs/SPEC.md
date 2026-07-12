# Pawprint — Digital Bullet Journal Spec

Living design doc, built up piece by piece alongside implementation. Update it as decisions change.

## Overview

Pawprint is a digital bullet journal.

- **Single-user, no auth — for now, this is temporary.** No `User` model, no sessions/login today,
  but multi-user support with auth is expected later; avoid designs that would be painful to
  retrofit a `User`/owner scope onto.
- **Current MVP scope: rapid logging + Daily Log only.** Monthly Log, Future Log, custom
  collections, and the Index are intentionally out of scope for now.
- **History-preserving migration.** Moving a task instead of just editing its date creates a new
  linked task and marks the original with a status reflecting what happened to it, mirroring the
  paper bullet-journal ritual (and giving an audit trail for free later, e.g. "this got pushed 3
  times").

## Data model

### `tasks` (model `Task`)

The only table built so far. Originally designed as a generic `entries`/`Entry` table with an
`entry_type` column (task/event/note), but that was dropped in favor of dedicated tables per
concept — this table now only ever holds tasks. See "Planned, not yet built" below for the rest.

| column | type | notes |
|---|---|---|
| `title` | string, not null, max 255 | the task summary  |
| `description` | text, nullable | optional longer body for additional task details |
| `log_year` | integer, not null | validated `>= 2000` |
| `log_month` | integer, not null | validated `1..12` |
| `log_day` | integer, nullable | validated `1..31` via `allow_nil: true` — nil is allowed, matching the deferred-task design below |
| `status` | enum, default `open` | `open`, `in_progress`, `completed`, `cancelled`, `deferred`, `migrated`, `archived` |
| `priority` | boolean, default `false` | the `*` signifier |
| `created_from_id` | bigint, nullable, self-referential FK → `tasks.id` | lineage pointer, see below |
| `created_at` / `updated_at` | timestamps | |

A virtual `date` attribute (`attr_accessor`, not a column) accepts a `Date`/`Time`/parseable string
and is split into `log_year`/`log_month`/`log_day` via a `before_validation` callback
(`split_date`) — this is how callers (e.g. the API params) set the date in one shot instead of
three separate fields.

Beyond the per-field range checks above, a `log_date_must_be_valid` validation rejects combinations
that don't form a real calendar date (e.g. `log_month: 2, log_day: 30`), adding the error to `:date`
— `log_day` defaults to `1` for this check when nil, since deferred tasks have no day yet.

`Task#log_date` builds the same `Date` for read purposes (used in the API JSON shape below) —
`log_day || 1`, so a deferred task's `log_date` reads as the 1st of its month rather than raising or
returning nil.

**Why split `log_year`/`log_month`/`log_day` instead of a single date column:** a task can be
placed in a monthly log without a specific day assigned yet. `log_year` and `log_month` are always
present; `log_day` is only set once the task has a specific day (either logged directly to a day,
or later given one).

**Why `created_from_id` does double duty:** when a task is moved, a new `Task` row is created and
`created_from_id` on the new row points back at the original. The same column covers two distinct
moves, distinguished by whether the new row has a `log_day`:

- **Deferred** — moved to a monthly log with no specific day. New row has `log_day: nil`. The
  *original* row's `status` is set to `deferred`.
- **Migrated** — specifically for a task that wasn't (or won't be) completed on the day it was
  logged, and gets carried forward to the *next* day, mirroring the paper bullet-journal migration
  ritual. New row has `log_day` set to the next day. The *original* row's `status` is set to
  `migrated`. This is deliberately **not** the same thing as "rescheduling" or just editing a
  task's date to move it to an arbitrary day — there's no general-purpose "change the date" event;
  migration only ever carries an incomplete task forward one day at a time.

So `status` on a task tells you what happened to *that row*, and `created_from_id` on its successor
tells you where it went.

### Status transitions (`TaskStateMachine` concern, AASM)

`Task` includes `TaskStateMachine` (`app/models/concerns/task_state_machine.rb`), which wires up
the `status` enum as an [AASM](https://github.com/aasm/aasm) state machine (`aasm column: :status,
enum: true`) instead of allowing free assignment of `status`.

Events and their transitions:

| event | from | to |
|---|---|---|
| `start` | `open` | `in_progress` |
| `stop` | `in_progress` | `open` |
| `complete` | `open`, `in_progress` | `completed` |
| `cancel` | `open`, `in_progress` | `cancelled` |
| `defer` | `open`, `in_progress` | `deferred` |
| `migrate` | `open`, `in_progress` | `migrated` |
| `archive` | `open`, `in_progress` | `archived` |
| `reopen` | `completed`, `cancelled`, `archived` | `open` |

Helper methods on `Task`:
- `available_events` — permissible events from the current state, as `{ event:, label: }` pairs
  (labels come from `TaskStateMachine::EVENT_DISPLAY_NAMES`, e.g. `start` → `"Start Task"`).
- `apply_event(name)` — applies the named event if permissible (`event_applyable?`), returns falsy
  otherwise instead of raising.
- `deletable?` — false when `status` is `deferred` or `migrated` (`NON_DELETABLE_STATUSES`); a
  `before_destroy` callback (`ensure_deletable`) blocks destroying a task in either state, since
  those tasks are lineage pointers other tasks were created from.

`Task.scoped_by(type:, date:, status: nil)` is the query entry point used by the API: `type` is
`"daily"` or `"monthly"`, `date` selects the year/month(/day), and when no `status` filter is
given the `unarchived` scope is applied (archived tasks are hidden by default).

## API

JSON API under `/api/v1`, routed via `namespace :api do namespace :v1 do ... end end` in
`config/routes.rb`.

- **`Api::BaseController`** (`app/controllers/api/base_controller.rb`) — shared base for API
  controllers. Skips CSRF token verification (`skip_before_action :verify_authenticity_token`,
  since this is a JSON API, not form posts). Rescues `ActionController::ParameterMissing` → 400
  and `ActiveRecord::RecordNotFound` → 404, both rendered as `{ errors: [...] }`.
- **`Api::V1::TasksController`** (`app/controllers/api/v1/tasks_controller.rb`) —
  `resources :tasks, only: %i[index create update destroy]` plus a member route `patch
  :transition`.
  - `index` — builds a `TaskFilter` from `params[:filter]`, calls `Task.scoped_by` if valid,
    otherwise returns an empty set (no 422 on bad filters, just `Task.none`).
  - `create` / `update` — standard, permitted params `:title, :description, :date, :priority`.
  - `transition` — applies a state-machine event named in `params[:event]` via `@task.apply_event`;
    422 if the event isn't permissible from the current state.
  - `destroy` — standard; will 422 via `deletable?`/`ensure_deletable` if the task is `deferred` or
    `migrated`.
  - JSON shape: `{ only: [:id, :title, :description, :status, :priority], methods: [:log_date,
    :available_events] }` — inlined in the controller for now (`TODO` comment notes moving to a
    serializer once more than one class needs this shape).
- **`TaskFilter`** (`app/models/task_filter.rb`) — plain `ActiveModel::Model` (not an AR model)
  used to validate `index` query params before hitting the DB: `type` (`"daily"`/`"monthly"`) and
  `date`. Invalid filters just short-circuit `index` to an empty list rather than erroring.

Routing note: there's no `root` route — this app is API-only, no web-facing controllers exist. The
default `/up` health check route is still commented out — see "Known issues" below.

## Testing

RSpec is the test framework. `config/application.rb` sets
`config.generators { |g| g.test_framework :rspec, fixtures: true }` so generators produce RSpec
specs under `spec/`. `bundle exec rspec` runs the suite; `bin/rubocop` covers `spec/**/*` too (see
`.rubocop.yml`'s `Style/StringLiterals` override).

Test data uses FactoryBot — the plain `factory_bot` gem, not `factory_bot-rails`, so it isn't
auto-wired: `spec/rails_helper.rb` manually adds `config.include FactoryBot::Syntax::Methods` and
`config.before(:suite) { FactoryBot.find_definitions }`. Factories live in `spec/factories/`.

`spec/helpers/controller_helpers.rb` defines a `json_response` helper (`JSON.parse(response.body)`)
mixed into `type: :request`/`type: :controller` specs via `rails_helper.rb`; all request specs use
it instead of parsing `response.body` inline.

Current coverage:
- `spec/models/task_spec.rb` — `Task` validations, defaults, status enum, `created_from` association.
- `spec/models/task_filter_spec.rb` — `TaskFilter` validations and `#to_query`.
- `spec/models/concerns/task_state_machine_spec.rb` — every AASM transition, invalid-transition
  errors, `available_events`/`available_event_names`, `event_applyable?`, `apply_event`,
  `.event_display_name`.
- `spec/requests/api/v1/tasks_spec.rb` — request specs for all five `Api::V1::TasksController`
  actions (`index`/`create`/`update`/`transition`/`destroy`), success and failure paths. There is no
  dedicated spec for `Api::BaseController` — its CSRF skip and both `rescue_from` handlers (missing
  `filter`/`task` param → 400, unknown task id → 404) are exercised indirectly through these
  `TasksController` request specs instead, since it has no standalone route to hit directly.

## Planned, not yet built

Noted here so the context isn't lost before we get to them:

- **`Event`** — separate table, not a `tasks` row. Events don't carry task status/lifecycle.
- **`Inspiration`** — separate table. No date columns — inspirations aren't scoped to a
  day/month/year like tasks are.
- **RSpec system specs.** The `system-test` job in `.github/workflows/ci.yml` still runs Minitest's
  `bin/rails test:system` task. This is a no-op today — a `test/system` directory never existed in
  this app, and no RSpec `type: :system` specs exist either — so the job currently does nothing
  functional (just spins up Postgres + Ruby for zero tests). Left as-is intentionally for now. To
  make it real later: configure a Capybara driver in `spec/rails_helper.rb` and add specs under
  `spec/system/`; the `capybara`/`selenium-webdriver` gems are already in the Gemfile's `:test`
  group, just unused so far.

None of these have a finalized schema yet; they'll get their own section here when designed.

## Known issues

- **The default `/up` health check route is still commented out**, with no replacement — load
  balancers/uptime monitors relying on it (see CLAUDE.md) get no response. Since this app is
  API-only, this is the one piece of default routing worth restoring even though `root` itself was
  correctly removed.
