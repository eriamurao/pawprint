# Pawprint

Pawprint is a digital bullet journal.

**Current state:** the project is API-only — there's no `root` route and no web-facing
controllers/views yet. The UI layer hasn't been decided: it may end up being server-rendered Rails
views (Hotwire/Turbo/Stimulus are already in the Gemfile) or a separate frontend (e.g. React)
talking to the JSON API. Don't assume either direction when picking up work here.

This project is built with the help of [Claude Code](https://claude.com/claude-code), but all
code is still reviewed, finalized, and committed by developers. Project-specific instructions for
it live in `CLAUDE.md`. Custom slash commands for it (`.claude/commands/`) are still a work in
progress and mostly empty right now.

## Prerequisites

- Ruby, matching the version in `.ruby-version` (currently `4.0.2`)
- PostgreSQL running locally and reachable with the credentials in `config/database.yml`
  (`postgres`/`postgres` on `localhost:5432` for development/test — matches the `postgres`
  service container used in CI)

## Getting started

1. Clone the repo and `cd` into it.
2. Install the Ruby version pinned in `.ruby-version` (via `rbenv`, `asdf`, `rvm`, etc.).
3. Run `bin/setup`. This installs gems, prepares the database (create + migrate + seed), and
   clears logs/tmp, then starts the dev server. Pass `--skip-server` to stop after setup, or
   `--reset` to also run `db:reset`.
4. If you stopped short of the server in step 3, start it with `bin/dev`.
5. The app has no `root` route — hit the API directly, e.g. `GET /api/v1/tasks?filter[type]=daily&filter[date]=2026-07-12`.

## Tests, linting, and CI

The essentials:

```
bundle exec rspec   # run the test suite
bin/rubocop         # style check
```

For the full command reference (single-file/single-line test runs, security scans, the local
`bin/ci` pipeline, database commands) see the **Commands** section of `CLAUDE.md` — it isn't
repeated here to avoid the two files drifting out of sync.

## Where to look next

- **`CLAUDE.md`** — commands, stack, architecture notes, and coding guidelines (also what Claude
  Code reads automatically). Start here for anything about how the codebase is organized or how
  to work in it.
- **`docs/SPEC.md`** — the living design doc for the data model, the `Task` status state machine,
  and the `/api/v1` API contract. This is the source of truth for *what* the app does; update it
  alongside any change to the data model or API.
