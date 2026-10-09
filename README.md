# E-Rekini — Simple Invoicing for Latvian Small Businesses

**Status: MVP v0.1 — work in progress**

> **Full implementation plan → [PLAN.md](PLAN.md)** — includes regulatory background, data model, phased feature roadmap, and technical decisions.

This is the first working version of what will eventually become [viegli-rekini.lv](https://viegli-rekini.lv) — a simple, no-nonsense invoicing tool for Latvian freelancers and small businesses.

I'm building this for two reasons: (1) it's a real product I want to exist, and (2) it's my primary Rails learning project. I'm documenting my architectural decisions here as notes to my future self — the reasoning behind each choice, not just what was chosen.

---

## What it does (v0.1)

- Manage clients with full address and VAT number fields
- Manage reusable products with default prices and VAT rates
- Create invoices with multiple line items and a product picker
- Automatic calculations — subtotal, VAT, total
- Sequential invoice numbers (INV-0001, INV-0002, …)
- Invoice lifecycle: `draft → sent → paid`, with `void` as an escape hatch
- Print-ready invoice layout (HTML + print CSS) and downloadable PDF (ferrum_pdf / headless Chrome)
- Account settings for company details, address, and bank information
- Single user per account for now; multi-user and multi-location are near-term (data model ready)

---

## Tech stack

| Layer | Choice | Why |
|-------|--------|-----|
| Framework | Rails 8 | Learning Rails properly; using latest stable |
| Database | SQLite3 | Right choice for this stage — simple, zero-config; Litestream backups planned |
| Auth | Rails 8 built-in | New in Rails 8 — no Devise needed for simple cases |
| CSS | Custom vanilla (CUBE CSS) | CUBE CSS methodology with Every Layout primitives, OKLCH color tokens, logical properties |
| Frontend | Hotwire (Turbo) | Rails default — SPA-feel without writing JS |
| Testing | Minitest | Rails default; system tests + model/service unit tests |
| Deployment | OVHCloud + Kamal 2 | Docker-based deploy; Litestream → Cloudflare R2 backups planned (hosting not started) |

---

## Architecture decisions and why

### Why SQLite3

SQLite3 is the database for this project. For a single-user invoicing app at MVP stage, it's the pragmatic choice:

- **Zero configuration** — no server process to manage, no credentials, no connection pooling. The database is a single file.
- **Litestream backups (planned)** — continuous replication to Cloudflare R2, not configured yet. In the event of server failure, the database can be restored to the exact point of failure.
- **Production-tested** — SQLite3 handles concurrency well for low-write workloads. Rails 8's `RETURNING` clause support and WAL mode make it a solid production database for this use case.
- **Scale when needed** — if the app outgrows SQLite3, the data can be migrated to PostgreSQL. But that day is not today.

### Schema format: `schema.rb`

The app uses `config.active_record.schema_format = :ruby` (`config/application.rb`), so `db/schema.rb` is the source of truth. Rails 8.1's `schema.rb` preserves DB check constraints (see `invoices_status_check`, `clients_vat_regime_check` in the schema), so the earlier idea of switching to `structure.sql` turned out to be unnecessary. If a future feature needs something `schema.rb` can't express (custom functions, partial indexes), revisit `schema_format = :sql` then.

**Reference:** Sustainable Web Development with Ruby on Rails, Ch. 14

### Database constraints vs. Rails validations — both, for different reasons

They serve different purposes:

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

When you need a non-standard action (like "send this invoice"), the tempting approach is to add a custom controller action:

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

Because Rails' seven standard actions (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`) are universally understood. Every Rails developer knows what a `create` action does. Custom action names (`send`, `mark_paid`) are unique to your app and require explanation.

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
  └── has_many :products
  └── has_many :invoices
  └── Fields: name, company_name, vat_number, company_reg,
              address, city, postal_code, country,
              bank_name, bank_account, bank_swift

User
  └── belongs_to :account

Client (belongs_to :account)
  └── has_many :invoices
  └── Fields: name, company_name, email, vat_number,
              address, city, postal_code, country

Product (belongs_to :account)
  └── Fields: name, description, unit_price_cents, vat_rate

Invoice (belongs_to :account, belongs_to :client)
  └── has_many :line_items
  └── status: draft | sent | paid | void
  └── Calculated: subtotal, vat_total, total (not stored)

LineItem (belongs_to :invoice)
  └── description, quantity, unit_price_cents, vat_rate, position
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

**Prerequisites:** Ruby 3.3+, SQLite3 (included with Rails).

```bash
git clone https://github.com/Ikass/viegli-rekini
cd viegli-rekini
bin/setup
bin/dev
```

`bin/setup` installs gems, creates and migrates the database, and seeds a demo account with sample clients, products, and invoices.

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

These are planned for later versions (PDF download was originally listed here but is now shipped via `ferrum_pdf`):

| Feature | Version |
|---------|---------|
| Email delivery (send invoice to client) | v0.2 |
| Multi-user accounts (invite team members) | v0.2 |
| Latvian/English bilingual UI | v0.2 |
| Overdue reminders and background jobs | v0.3 |
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
