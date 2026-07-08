# Pawprint — Digital Bullet Journal Spec

Living design doc, built up piece by piece alongside implementation. Update it as decisions change.

## Overview

Pawprint is a digital bullet journal.

- **Single-user, no auth.** No `User` model, no sessions/login.
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
| `content` | text | the task's text |
| `log_year` | integer, not null | |
| `log_month` | integer, not null | |
| `log_day` | integer, nullable | null means this task lives in a monthly log with no specific day yet (see `deferred` below) |
| `status` | enum, default `open` | `open`, `in_progress`, `completed`, `cancelled`, `deferred`, `rescheduled` |
| `priority` | boolean, default `false` | the `*` signifier |
| `created_from_id` | bigint, nullable, self-referential FK → `tasks.id` | lineage pointer, see below |
| `created_at` / `updated_at` | timestamps | |

**Why split `log_year`/`log_month`/`log_day` instead of a single date column:** a task can be
placed in a monthly log without a specific day assigned yet. `log_year` and `log_month` are always
present; `log_day` is only set once the task has a specific day (either logged directly to a day,
or later given one).

**Why `created_from_id` does double duty:** when a task is moved, a new `Task` row is created and
`created_from_id` on the new row points back at the original. The same column covers two distinct
moves, distinguished by whether the new row has a `log_day`:

- **Deferred** — moved to a monthly log with no specific day. New row has `log_day: nil`. The
  *original* row's `status` is set to `deferred`.
- **Rescheduled** — moved to a specific day. New row has `log_day` set. The *original* row's
  `status` is set to `rescheduled`.

So `status` on a task tells you what happened to *that row*, and `created_from_id` on its successor
tells you where it went.

## Testing

RSpec, not Minitest, is the test framework. `config/application.rb` sets
`config.generators { |g| g.test_framework :rspec, fixtures: true }` so generators produce RSpec
specs under `spec/` instead of Minitest tests under `test/` (the `test/` directory has been
removed). `bundle exec rspec` runs the suite; `bin/rubocop` covers `spec/**/*` too (see
`.rubocop.yml`'s `Style/StringLiterals` override).

Test data uses FactoryBot — the plain `factory_bot` gem, not `factory_bot-rails`, so it isn't
auto-wired: `spec/rails_helper.rb` manually adds `config.include FactoryBot::Syntax::Methods` and
`config.before(:suite) { FactoryBot.find_definitions }`. Factories live in `spec/factories/`.

## Planned, not yet built

Noted here so the context isn't lost before we get to them:

- **`Event`** — separate table, not a `tasks` row. Events don't carry task status/lifecycle.
- **`Note`** — separate table, not a `tasks` row. Freeform note content, no status/lifecycle.
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
