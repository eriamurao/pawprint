# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is a Rails 8.1 application generated via `rails new` and not yet built out — there are no
custom models, controllers, or routes yet (`config/routes.rb` only has the health check route).
Treat existing scaffolding (empty `app/models/concerns`, `app/controllers/concerns`, `lib/tasks`,
`test/*` dirs with only `.keep` files) as placeholders, not as evidence of a pattern to follow.

## Stack

- Ruby 4.0.2, Rails ~> 8.1.3, PostgreSQL (via `pg`)
- Propshaft for assets, importmap-rails for JS (no bundler/webpack/node), Turbo + Stimulus (Hotwire)
- Solid Queue (jobs), Solid Cache (cache), Solid Cable (Action Cable) — all database-backed, no Redis
- Puma + Thruster, deployed via Kamal (see `config/deploy.yml`, `.kamal/`)
- Active Storage for file uploads (`image_processing` gem included for variants)

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

Tests (Minitest, not RSpec):
```
bin/rails test                          # full test suite
bin/rails test test/models/foo_test.rb  # single file
bin/rails test test/models/foo_test.rb:12  # single test at line
bin/rails test:system                   # system tests (Capybara + Selenium)
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
Defined in `config/ci.rb` using `ActiveSupport::ContinuousIntegration`. Runs setup, rubocop,
the three security scans, `bin/rails test`, and a seed-replant check, in that order. Add new
CI steps there rather than only in the GitHub workflow.

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

- Standard Rails app layout under `app/` — MVC, no API-only mode, no engines/modules split yet.
- `SOLID_QUEUE_IN_PUMA` is enabled in production (`config/deploy.yml`), meaning the job
  supervisor runs embedded in the Puma process rather than as a separate `bin/jobs` service,
  unless/until a dedicated job server is split out.
- Kamal deploy config (`config/deploy.yml`) currently targets a single placeholder server
  (`192.168.0.1`) with a local registry — update before any real deploy.
- Local Postgres credentials in `config/database.yml` (development/test) are `postgres`/`postgres`
  on `localhost:5432` — matches the `postgres` service container used in CI.
