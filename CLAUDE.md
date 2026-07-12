# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Pawprint is a digital bullet-journal app, API-only so far (no `root` route, no web-facing
controllers/views). **Read `docs/SPEC.md` fresh each session** — it's the living design doc for
the data model, state machine, and API, and is kept up to date alongside the code; this file only
covers commands and stack-level architecture.

Single-user, no auth today — no `User` model, no sessions/login — but multi-user support is
expected later, so avoid designs that would be painful to retrofit an owner scope onto.

## Stack

- Ruby 4.0.2, Rails ~> 8.1.3, PostgreSQL (via `pg`)
- Propshaft for assets, importmap-rails for JS (no bundler/webpack/node), Turbo + Stimulus (Hotwire) —
  unused so far since there's no web frontend yet
- Solid Queue (jobs), Solid Cache (cache), Solid Cable (Action Cable) — all database-backed, no Redis
- Puma + Thruster, deployed via Kamal (see `config/deploy.yml`, `.kamal/`)
- Active Storage for file uploads (`image_processing` gem included for variants) — not yet used by any model
- `aasm` for the `Task` status state machine
- RSpec (`rspec-rails`) for tests + `factory_bot` (plain gem, not `factory_bot-rails`) +
  `capybara`/`selenium-webdriver` (present but no system specs exist yet)

## General coding guidelines

- Prioritize code correctness and clarity; speed and efficiency are secondary unless a task specifically calls for it.
- Use full words for variable and method names — avoid abbreviations.
- Prefer simple, single-responsibility methods.
- Make sure to document any errors that are raised or returned.
- Log every caught error with enough context to diagnose it — never fail silently.
- Add specs (RSpec) for all new code.
- Avoid comments that restate what the code does — only comment the non-obvious "why".
- Treat all external input as untrusted — validate before use.

## Ruby/Rails coding guidelines

- Use structured data, like `Data` or `Struct`, instead of unstructured anonymous hashes.
- Check for nil values early. Do not litter code with `&.`.

## Commands

Setup:
```
bin/setup            # bundle install, db:prepare, clear logs/tmp, then starts bin/dev
bin/setup --skip-server
bin/setup --reset    # also runs db:reset
```

Run the app:
```
bin/dev               # starts bin/rails server
```

Tests (RSpec):
```
bundle exec rspec                              # full suite
bundle exec rspec spec/models/task_spec.rb     # single file
bundle exec rspec spec/models/task_spec.rb:12  # single example at line
```

Lint / static analysis:
```
bin/rubocop           # style (rubocop-rails-omakase house style — do not fight it with custom cops)
bin/brakeman          # security static analysis
bin/bundler-audit     # gem vulnerability audit
bin/importmap audit   # JS dependency vulnerability audit
```

Full CI pipeline locally (mirrors `.github/workflows/ci.yml`):
```
bin/ci
```
Defined in `config/ci.rb` using `ActiveSupport::ContinuousIntegration`. Runs setup, rubocop, the
three security scans, `bundle exec rspec`, and a seed-replant check, in that order. Add new CI
steps there rather than only in the GitHub workflow. The GitHub workflow's `system-test` job is
commented out — no RSpec system specs exist yet.

Database:
```
bin/rails db:prepare   # create + migrate + seed as needed (idempotent)
bin/rails db:migrate
bin/rails db:seed:replant
```
Note: the app uses **three separate databases** beyond primary — cache, queue, and cable
(`db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb`), each with their own
migrations path (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate` in production).
Migrations for the primary app go in `db/migrate` as usual.

## Architecture notes

- Status transitions go through the `TaskStateMachine` concern (`app/models/concerns/`, AASM-backed)
  rather than free assignment of `status` — always change status via an event (`apply_event`/the
  generated `event!` methods), never `task.status =`.
- `SOLID_QUEUE_IN_PUMA` is enabled in production (`config/deploy.yml`), meaning the job
  supervisor runs embedded in the Puma process rather than as a separate `bin/jobs` service,
  unless/until a dedicated job server is split out.
- Kamal deploy config (`config/deploy.yml`) currently targets a single placeholder server
  (`192.168.0.1`) with a local registry — update before any real deploy.
- Local Postgres credentials in `config/database.yml` (development/test) are `postgres`/`postgres`
  on `localhost:5432` — matches the `postgres` service container used in CI.
- `.rubocop.yml` overrides the omakase style to require single-quoted string literals across
  `app/`, `config/`, `lib/`, `spec/`, `test/`, `Gemfile`, and `db/seeds.rb`.
