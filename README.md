# Invoicio — Simple Invoicing for Latvian Small Businesses

**Status: MVP v0.1 — work in progress**

This is the first working version of what will eventually become [viegli-rēķini.lv](https://viegli-rekini.lv) — a simple, no-nonsense invoicing tool for Latvian freelancers and small businesses.

I'm building this for two reasons: (1) it's a real product I want to exist, and (2) it's my primary Rails learning project. I'm documenting my architectural decisions here as notes to my future self — the reasoning behind each choice, not just what was chosen.

**Live demo:** _[Render URL — added after first deploy]_

---

## What it does (v0.1)

- Manage clients (name, company, VAT number)
- Create invoices with multiple line items
- Automatic calculations — subtotal, VAT, total
- Sequential invoice numbers (INV-0001, INV-0002, …)
- Invoice lifecycle: `draft → sent → paid`, with `void` as an escape hatch
- Print-ready invoice layout (HTML + print CSS — no PDF gem)
- Single-user for now; data model is ready for multi-tenancy

---

## Tech stack

| Layer | Choice | Why |
|-------|--------|-----|
| Framework | Rails 8 | Learning Rails properly; using latest stable |
| Database | PostgreSQL | Right choice for financial data |
| Auth | Rails 8 built-in | New in Rails 8 — no Devise needed for simple cases |
| CSS | Pico CSS (v0.1) | Semantic, classless CSS — fast to get something decent looking. Will migrate to custom vanilla CSS in v0.2 |
| Frontend | Hotwire (Turbo) | Rails default — SPA-feel without writing JS |
| Testing | Minitest | Rails default; system tests + model/service unit tests |
| Deployment | Render | Free tier PostgreSQL; `git push` deploys |

---

## Architecture decisions and why

### Why PostgreSQL, not SQLite

SQLite is fine for most things, and I use it in other projects. But for financial data, PostgreSQL is the correct choice for a few reasons:

- **`timestamptz` column type** — PostgreSQL stores timestamps with timezone info. SQLite doesn't. For invoices with due dates, getting timezone handling wrong is a real bug.
- **Check constraints** — PostgreSQL can enforce that `status` is always one of a known set of values at the database level, not just in Ruby. More on this under "database constraints" below.
- **Production parity** — the app will eventually run on a proper PostgreSQL server. Better to develop against the real thing.

### Why `structure.sql` instead of `schema.rb`

Rails can represent your database schema in two formats. `schema.rb` is simpler but lossy — it can't represent database-specific features like check constraints, custom functions, or partial indexes. `structure.sql` is a direct SQL dump of your schema, so it preserves everything exactly.

I set `config.active_record.schema_format = :sql` in `config/application.rb`. This costs nothing and means my schema file always reflects the real database state.

**Reference:** Sustainable Web Development with Ruby on Rails, Ch. 14

### Database constraints vs. Rails validations — both, for different reasons

This was a key insight from reading about Rails architecture. They serve different purposes:

- **Validations** (`validates :name, presence: true`) — these run in Ruby before saving. They produce user-friendly error messages. But they can be bypassed: `invoice.update_column(:status, "nonsense")` skips validations entirely.
- **Database constraints** (`null: false`, `foreign_key: true`, check constraints) — these live in the database and cannot be bypassed. They're the last line of defence for data integrity.

So the rule is: use validations for UX (error messages), use database constraints for correctness. Both are needed.

In practice: every required column has `null: false` in the migration. Every `references` column has `foreign_key: true`. The `status` enum has a check constraint so the database will reject any value that isn't in the allowed list, even if someone bypasses Rails entirely.

**Reference:** Sustainable Web Development with Ruby on Rails, Ch. 14 + Ch. 16

### Business logic lives in `app/services/`, not in models or controllers

This is the pattern I'm trying to be disciplined about. The rule is:

- **Models** — relationships, validations, scopes, and pure calculation methods (like `total`). No writes, no side effects.
- **Controllers** — receive a request, find the right record, call a service, redirect or render. One instance variable per action. No logic.
- **Services** — everything else. State transitions, any operation that involves multiple steps or side effects.

For invoice state transitions, each transition is its own service class (`InvoiceSender`, `InvoicePaymentRecorder`, `InvoiceVoider`). Each returns a `Result` struct so the caller always knows explicitly whether it succeeded.

The reason for this separation: models that contain business logic become fragile. When the business rule changes, you're editing a class that other parts of the app depend on heavily. Service objects are easy to change, easy to test in isolation, and easy to reason about.

**Reference:** Sustainable Web Development with Ruby on Rails, Ch. 5 + Ch. 15

### Status transitions as REST resources, not custom controller actions

This one took me a while to understand. When you need a non-standard action (like "send this invoice"), the tempting approach is to add a custom controller action:

```ruby
# Tempting but wrong
POST /invoices/:id/send
```

The Rails-idiomatic approach is to model the *transition itself* as a resource:

```ruby
# Correct
POST /invoice_sends        # body contains invoice_id
POST /invoice_payments
POST /invoice_voids
```

Why? Because Rails' seven standard actions (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`) are universally understood. Every Rails developer knows what a `create` action does. Custom action names (`send`, `mark_paid`) are unique to your app and require explanation.

It also forces cleaner thinking: "sending an invoice" is a thing that happens, not a property of the invoice.

**Reference:** Sustainable Web Development with Ruby on Rails, Ch. 6

### Multi-tenancy foundation (not yet built, but planned)

Every `Client` and `Invoice` has an `account_id` foreign key. All queries in controllers go through `current_user.account` rather than the model directly:

```ruby
# This, always:
@invoices = current_user.account.invoices

# Never this:
@invoices = Invoice.all
```

Right now there's only one account (the demo user's). But the data model is correct for multi-tenancy from day one. Adding a second tenant later requires no schema changes — just account creation and proper session handling.

This is one of those things that's cheap to do at the start and expensive to retrofit later.

### Storing money as integers (cents), not decimals

`unit_price` and `quantity` are stored as follows:
- `unit_price_cents` — integer, in euro cents (e.g., 5000 = €50.00)
- `quantity` — decimal (you might invoice for 1.5 hours)

Why cents? Floating point arithmetic is not reliable for money. `0.1 + 0.2` in a computer does not equal `0.3` exactly. Storing prices as integers and dividing by 100 for display eliminates an entire class of subtle bugs. Financial software should always do this.

**To learn more:** search "floating point money representation" — it's a classic problem.

---

## Data model

```
Account
  └── has_many :users
  └── has_many :clients
  └── has_many :invoices

User
  └── belongs_to :account

Client (belongs_to :account)
  └── has_many :invoices

Invoice (belongs_to :account, belongs_to :client)
  └── has_many :line_items
  └── status: draft | sent | paid | void
  └── Calculated: subtotal, vat_total, total (not stored — derived from line items)

LineItem (belongs_to :invoice)
  └── description, quantity, unit_price_cents, vat_rate
```

---

## Invoice status lifecycle

```
draft ──→ sent ──→ paid
  │          │        │
  └──────────┴────────┴──→ void
```

Invalid transitions are rejected at the service layer. You cannot go from `draft` directly to `paid`. You cannot un-void an invoice.

---

## Development setup

**Prerequisites:** Ruby 3.3+, PostgreSQL running locally.

```bash
git clone https://github.com/reinisvaivars/invoicio
cd invoicio
bin/setup
bin/dev
```

`bin/setup` installs gems, creates and migrates the database, and seeds a demo account with sample clients and invoices.

Log in at `http://localhost:3000` with `demo@example.com` / `password`.

---

## Running tests

```bash
bin/ci
```

Runs the full suite: model tests, service tests, system tests, `brakeman` security scan, `bundler-audit` dependency check.

Individual test files:

```bash
bin/rails test test/models/invoice_test.rb
bin/rails test test/services/
bin/rails test:system
```

---

## What's intentionally out of scope for v0.1

These are planned for later versions:

| Feature | Version |
|---------|---------|
| Email delivery (send invoice to client) | v0.2 |
| Multi-user accounts (invite team members) | v0.2 |
| Latvian/English bilingual UI | v0.2 |
| Overdue reminders and background jobs | v0.3 |
| PDF download | v0.3 |
| Subscription billing | v1.0 |
| Latvian e-invoice standard (eFaktura) | v1.0 |

---

## What I'd do differently with more time

- Add `pagy` for pagination on the invoices index — right now it lists everything
- Extract a `MoneyAmount` value object instead of raw cents arithmetic scattered in views
- Add Lograge for structured production logging
- Set up Sentry for error tracking from day one

---

## Learning resources used

- *Sustainable Web Development with Ruby on Rails* — David Bryant Copeland (architecture patterns)
- *Agile Web Development with Rails 8* — Sam Ruby et al. (Rails fundamentals)
- [guides.rubyonrails.org](https://guides.rubyonrails.org) — official Rails guides
- [render.com/docs](https://render.com/docs) — deployment
