# AGENTS.md — Viegli-Rēķini

Coding agent context for the Viegli-Rēķini e-invoicing Rails app. Read this before making any changes.

> **Obsidian vault reference docs:** `01.Projects/Rails/viegli-rekini/` in MainVault:
> `lv-invoice-legal-requirements.md`, `viegli-rekini-invoice-generation-architecture.md`

---

## What this app is

A focused Rails 8 e-invoicing SaaS for Latvian small businesses. Multi-tenant at the `Account` level (one company per account). SQLite3.

Today each account has a single user; multi-user and multi-location are the near-term target (see `ARCHITECTURE.md` §"Phase 1B target"). Production domain: `vieglirekini.lv`.

Portfolio project — code quality and architectural clarity matter as much as feature completeness.

---

## Stack

- **Rails 8.1** — modern idioms; `params.expect()` for strong parameters
- **SQLite3**
- **Hotwire** — Turbo + Stimulus
- **Custom vanilla CSS** (CUBE CSS) — OKLCH color tokens, Every Layout primitives, logical properties
- **Minitest** — model, service, and system tests
- **Hetzner + Kamal 2** — deployment target; domain `vieglirekini.lv`; Litestream → Cloudflare R2 backups planned (hosting not started yet)

---

## Before a non-trivial change

1. Read `agents/docs/index.md` (the map)
2. Read `ARCHITECTURE.md` (the why)
3. Read the relevant contract / recipe / spec under `agents/docs/`
4. Inspect the closest existing implementation
5. Extend the pattern — don't invent a new shape for something that already has one

---

## Quick commands

| Task | Command |
|---|---|
| Run everything CI checks | `bin/ci` |
| Setup / reset dev env | `bin/setup` or `bin/setup --reset` |
| Start dev server | `bin/dev` (or `bin/setup` without `--skip-server`) |
| Single test file | `bin/rails test test/models/invoice_test.rb` |
| All model/service tests | `bin/rails test` |
| System tests | `bin/rails test:system` |
| Security scan | `bin/brakeman --quiet --no-pager` |
| Style check | `bin/rubocop` |

`bin/ci` runs: setup → rubocop → bundler-audit → importmap audit → brakeman → `bin/rails test` → seed replant → system tests.

---

## Operational gotchas

### Dev server must restart when new top-level directories are added

Zeitwerk caches the autoload tree at boot time. If you create a new file in a directory that did not exist when the server started (e.g. `app/services/invoice_sender.rb` when `app/services/` was empty or newly created), the running server will raise `NameError: uninitialized constant`.

**Fix:** Stop and restart `bin/dev`.

Tests are unaffected — each `bin/rails test` run boots a fresh environment.

### Background jobs and cache — Solid Queue/Cache is the intended future, not active yet

The intended stack is **Solid Queue** (background jobs) and **Solid Cache** (durable cache). The gems are currently commented out of the `Gemfile` (issues enabling them now), so production runs `config.active_job.queue_adapter = :async` and `config.cache_store = :memory_store` (in-process, non-durable). Consequences:

- `deliver_later` (e.g. the password-reset mail) runs in-process and is not durable across restarts.
- `bin/jobs`, `config/queue.yml`, `config/recurring.yml`, `config/cache.yml`, and `db/{queue,cache,cable}_schema.rb` are the **intended-future** Solid config, not active today. Don't delete them as dead; don't assume they work yet.
- When the gems are re-enabled: flip the adapters in `production.rb` and wire `SOLID_QUEUE_IN_PUMA`.

---

## Architecture rules

### Services

One service object per state transition, following the shape in `agents/docs/contracts/service-objects.md`.

### Controllers

- One instance variable per action (`@invoice`, `@client`, etc.)
- Use `find_by!` — never `find_by` (silent nil is a bug waiting to happen)
- No business logic — delegate to services
- Strong parameters: use `params.expect(user: [:email_address, :password])` (Rails 8.1), not `permit`
- All queries scoped through the tenancy boundary — see `agents/docs/contracts/tenancy.md`
- Foreign keys submitted in params (`invoice[client_id]`, etc.) must be resolved **through `Current.user.account`**, never trusted verbatim. A scoped `<option>` list in the view is not protection — validate the FK on the way in. See `tenancy.md` §"Foreign keys in params".

### Authorization (near-term — not yet defined)

There is no role/permission model today: any user of an account can do anything. Multi-user-per-account is a near-term requirement (to test with real users), which forces a roles decision (admin / accountant / member at minimum) before then. Until it lands, don't invent ad-hoc `if user.admin?` checks — decide the model once and apply it consistently. See `ARCHITECTURE.md` §"What's deliberately not built yet".

### Database migrations

- Every column that must exist: `null: false`
- Every `references`: `foreign_key: true, index: true`
- Status enum: also add a DB check constraint, not just the Rails enum
- Test constraints directly: `update_column` to bypass validations, confirm DB rejects
- Money stored as integer cents (`unit_price_cents`), not decimal — floating point is unsafe for money

### Views and partials

- Strict locals on every partial: `<%# locals: (invoice:) %>`
- No instance variables inside partials — ever
- Partials receive exactly what they need, nothing more
- Use `data-testid` attributes for system test selectors, not CSS classes

### Show views

Every show view follows the same structure as edit views — card sections with `section-label` headings, wrapped in a `.stack` container:

```erb
<h1><%= @record.name %></h1>

<div class="stack">
  <section aria-labelledby="details-heading" style="margin-block-end: var(--space-l);">
    <h2 id="details-heading" class="section-label">Section heading</h2>
    <div class="card">
      <div>                      <!-- ← inner div required for card padding -->
        <dl>
          <dt>Field label</dt>
          <dd><%= @record.field %></dd>
        </dl>
      </div>
    </div>
  </section>

  <div class="form-actions">
    <%# Primary action, destructive action, ghost "back" link %>
    <%= link_to "Edit", ..., class: "button" %>
    <%= button_to "Delete", ..., class: "button", data: { variant: "danger" } %>
    <%= link_to "Back", ..., class: "button", data: { variant: "ghost" } %>
  </div>
</div>
```

Key rules:
- `<h1>` sits **outside** the `.stack` wrapper
- Every `.card` **must** have an inner `<div>` — `.card > div` is what gets `padding: var(--space-m)` in CSS. A bare `<dl>` inside `.card` receives zero padding
- The button row uses `form-actions` (not `cluster`) — gives proper `margin-block-start` and `gap`
- The "back" link is a ghost button **inside** `form-actions`, not standalone

### Routes

Follow canonical REST. If a behaviour doesn't fit the 7 standard actions, it becomes a new resource.

```ruby
# Status transitions are new resources, not custom member actions
resources :invoice_sends, only: [:create]
resources :invoice_payments, only: [:create]
resources :invoice_voids, only: [:create]
```

Shallow nesting maximum one level:
```ruby
resources :invoices, shallow: true do
  resources :line_items, only: [:new, :create, :edit, :update, :destroy]
end
```

---

## Testing

- Run tests after every meaningful change: `bin/rails test`
- `test/test_helpers/session_test_helper.rb` provides `sign_in_as(user)` and `sign_out` for controller/integration tests
- User fixtures use `BCrypt::Password.create("password")` for password_digest
- Test DB constraints directly with `update_column` to bypass validations
- System tests use `data-testid` selectors, not CSS classes
- Coverage expected: model tests (totals, VAT, invoice number, transitions), service tests (valid/invalid), system tests (happy path)

---

## Conventions

- `frozen_string_literal: true` on every Ruby file
- Method and variable names read like prose — no abbreviations
- Prefer explicit over clever
- `bin/ci` must pass before considering anything shippable
- Commit messages: imperative mood, present tense ("Add invoice number generation")
- Maintain `LEARNING.md` (repo root) — durable decisions/lessons promoted from `agents/logs/`; updated by `/session-log` (per-session) and `/log-catchup` (reconciles git history after a gap)

---

## What's out of scope — do not build these

- Subscription billing
- Pagination

If asked to implement any of the above, flag it and ask for confirmation first. Fuller rationale lives in `ARCHITECTURE.md` ("What's deliberately not built yet").
