# AGENTS.md — Invoicio

Coding agent context for the Invoicio e-invoicing Rails app. Read this before making any changes.

---

## What this app is

A focused Rails 8 invoicing application. Single-user for now, but the data model is built for multi-tenancy. PostgreSQL. Deployed to Render.

This is a portfolio project — code quality and architectural clarity matter as much as feature completeness.

---

## Stack

- **Rails 8** — use modern Rails idioms; no legacy patterns
- **PostgreSQL** — not SQLite; use `structure.sql` (already configured)
- **Hotwire** — Turbo for navigation and form submissions; Stimulus for any JS behaviour
- **Vanilla CSS** — no Tailwind, no Bootstrap; CSS custom properties for tokens
- **Minitest** — system tests primary; model and service unit tests alongside
- **Render** — deployment target; environment variables via Render dashboard

---

## Architecture rules — follow these strictly

### Where logic lives

| Logic type | Location |
|---|---|
| Invoice state transitions | `app/services/` — one service per transition |
| Calculations (totals, VAT) | `Invoice` model methods — pure, no DB writes |
| HTTP orchestration | Controllers — thin, one instance var per action |
| Email rendering | Mailers — delegate sending to services |
| Data shape | Models — associations, validations, scopes only |

### Services pattern

Every service:
- One public method, explicitly named (not `call`)
- Returns `Result = Struct.new(:success, :invoice, keyword_init: true)`
- Callers check `result.success?` — never infer from model state

```ruby
# app/services/invoice_sender.rb
class InvoiceSender
  Result = Struct.new(:success, :invoice, keyword_init: true)

  def send_invoice(invoice:)
    return Result.new(success: false, invoice: invoice) unless invoice.draft?
    invoice.update!(status: :sent)
    Result.new(success: true, invoice: invoice)
  end
end
```

### Controllers

- One instance variable per action (`@invoice`, `@client`, etc.)
- All queries scoped through `current_user.account` — never bare `Invoice.find`
- Use `find_by!` — never `find_by` (silent nil is a bug waiting to happen)
- No business logic — delegate to services

```ruby
# Good
@invoice = current_user.account.invoices.find_by!(id: params[:id])

# Bad — never do this
@invoice = Invoice.find(params[:id])
```

### Database migrations

- Every column that must exist: `null: false`
- Every `references`: `foreign_key: true, index: true`
- Status enum: also add a DB check constraint, not just the Rails enum
- Test constraints directly: `update_column` to bypass validations, confirm DB rejects

### Views and partials

- Strict locals on every partial: `<%# locals: (invoice:) %>`
- No instance variables inside partials — ever
- Partials receive exactly what they need, nothing more

---

## Data model

```
Account
  - name: string, null: false

User
  - email: string, null: false, unique
  - password_digest: string, null: false
  - account_id: references Account, null: false

Client
  - account_id: references Account, null: false
  - name: string, null: false
  - email: string
  - company_name: string
  - vat_number: string

Invoice
  - account_id: references Account, null: false
  - client_id: references Client, null: false
  - invoice_number: string, null: false, unique (INV-0001 format)
  - issued_on: date, null: false
  - due_on: date, null: false
  - status: enum (draft, sent, paid, void), null: false, default: draft
  - notes: text

LineItem
  - invoice_id: references Invoice, null: false
  - description: string, null: false
  - quantity: decimal, null: false
  - unit_price: decimal, null: false (cents or decimal euros — decide and be consistent)
  - vat_rate: decimal, null: false, default: 0
  - position: integer (for ordering)
```

**Calculated on Invoice (no DB columns):**
- `subtotal` — sum of line item subtotals
- `vat_total` — sum of line item VAT amounts
- `total` — subtotal + vat_total

---

## Status lifecycle

```
draft → sent → paid
  ↓       ↓      ↓
void    void   void
```

Invalid transitions raise an error — they do not silently fail. Each transition is a separate service object.

- `InvoiceSender#send_invoice(invoice:)` — draft → sent
- `InvoicePaymentRecorder#record_payment(invoice:)` — sent → paid
- `InvoiceVoider#void_invoice(invoice:)` — any non-void → void

---

## Routes

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

## Testing expectations

Run tests after every meaningful change: `bin/rails test`

Coverage expected:
- `test/models/invoice_test.rb` — total calculations, VAT, invoice number generation, transition guards
- `test/services/` — one file per service, valid/invalid input, edge cases
- `test/system/` — full happy-path flows for creating and paying an invoice
- Constraint tests: `update_column` bypasses validations — confirm DB rejects

Use `data-testid` attributes in views for system test selectors, not CSS classes.

---

## Conventions

- `frozen_string_literal: true` on every Ruby file
- Method and variable names read like prose — no abbreviations
- Prefer explicit over clever
- `bin/ci` must pass before considering anything shippable
- Commit messages: imperative mood, present tense ("Add invoice number generation")

---

## Build plan — two evenings

This section tracks the MVP build plan. Check off completed steps before starting a session so you know exactly where to pick up.

### Evening 1 — Foundation

| # | Task | Status |
|---|------|--------|
| 1 | `rails new` with PostgreSQL, Propshaft | ✅ Done |
| 2 | Config: `structure.sql`, `timestamptz`, `frozen_string_literal` | ✅ Done |
| 3 | PostgreSQL installed, database created | ✅ Done |
| 4 | Rails 8 built-in authentication (User, Session, Current) | ✅ Done |
| 5 | `Account` model + `has_many :users`; `account_id` on users | ✅ Done |
| 6 | `RegistrationsController` — auto-creates Account on signup | ✅ Done |
| 7 | `Client` model + full CRUD, account-scoped | ✅ Done |
| 8 | `Invoice` + `LineItem` models and migrations | ⬜ Next |
| 9 | Invoice CRUD with nested line items form | ⬜ |

### Evening 2 — State machine, polish, deploy

| # | Task | Status |
|---|------|--------|
| 10 | Status transition services (`InvoiceSender`, `InvoicePaymentRecorder`, `InvoiceVoider`) | ⬜ |
| 11 | Transition routes as REST resources + controller actions | ⬜ |
| 12 | Transition buttons in UI — show only valid next actions | ⬜ |
| 13 | Invoices index grouped by status with totals | ⬜ |
| 14 | Print-ready invoice view (`layouts/print.html.erb` + print CSS) | ⬜ |
| 15 | `bin/setup`, `bin/dev`, `bin/ci` scripts | ⬜ |
| 16 | Model tests — totals, VAT, invoice number, blocked transitions | ⬜ |
| 17 | Service tests — valid/invalid transitions, edge cases | ⬜ |
| 18 | Seed file — demo account with sample clients and invoices | ⬜ |
| 19 | Deploy to Render — provision PostgreSQL, set ENV vars, run migrations | ⬜ |

### Current state (start of Evening 2)

What exists and works:
- Registration creates an Account and User in a transaction, then logs in automatically
- Login/logout via Rails 8 session auth with signed cookies
- Clients: full CRUD scoped through `Current.user.account`
- Pico CSS loaded from CDN; `application.css` for overrides
- Nav with sign-out button, logo links to root

What does NOT exist yet:
- `Invoice` and `LineItem` models — not generated
- Any invoice UI
- Status transitions
- Tests
- Seed data
- Deployment config

---

## What's out of scope — do not build these

- Email delivery
- Background jobs / Solid Queue
- Multi-user account management UI
- Subscription billing
- PDF generation (print CSS is sufficient)
- Pagination (add `pagy` only if seed data makes it painful to develop)
- Overdue reminders

If asked to implement any of the above, flag it and ask for confirmation first.
