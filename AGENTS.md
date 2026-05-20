# AGENTS.md — Invoicio

Coding agent context for the Invoicio e-invoicing Rails app. Read this before making any changes.

---

## What this app is

A focused Rails 8 invoicing application. Single-user for now, but the data model is built for multi-tenancy. PostgreSQL. Deployed to Render.

Portfolio project — code quality and architectural clarity matter as much as feature completeness.

---

## Stack

- **Rails 8.1.2** — modern idioms; `params.expect()` for strong parameters
- **PostgreSQL** — `structure.sql` configured (`config.active_record.schema_format = :sql`)
- **Hotwire** — Turbo + Stimulus
- **Pico CSS** from CDN + `application.css` for overrides
- **Minitest** — model, service, and system tests
- **Render** — deployment target

---

## Quick commands

| Task | Command |
|---|---|
| Run everything CI checks | `bin/ci` |
| Setup / reset dev env | `bin/setup` or `bin/setup --reset` |
| Start dev server | `bin/dev` (or `bin/setup` without `--skip-server`) |
| Single test file | `bin/rails test test/models/invoice_test.rb` |
| All model/service tests | `bin/rails test` |
| System tests | `bin/rails test:system` (currently commented out in `config/ci.rb`) |
| Security scan | `bin/brakeman --quiet --no-pager` |
| Style check | `bin/rubocop` |

`bin/ci` runs: setup → rubocop → bundler-audit → importmap audit → brakeman → `bin/rails test` → seed replant. System tests are optional and currently disabled in CI.

---

## Operational gotchas

### Dev server must restart when new top-level directories are added

Zeitwerk caches the autoload tree at boot time. If you create a new file in a directory that did not exist when the server started (e.g. `app/services/invoice_sender.rb` when `app/services/` was empty or newly created), the running server will raise `NameError: uninitialized constant`.

**Fix:** Stop and restart `bin/dev`.

Tests are unaffected — each `bin/rails test` run boots a fresh environment.

---

## Architecture rules

### Where logic lives

| Logic type | Location |
|---|---|
| Invoice state transitions | `app/services/` — one service per transition |
| Calculations (totals, VAT) | `Invoice` model methods — pure, no DB writes |
| HTTP orchestration | Controllers — thin, one instance var per action |
| Data shape | Models — associations, validations, scopes only |

### Services pattern

Every service:
- One public method, explicitly named (not `call`)
- Returns `Result = Struct.new(:success, :invoice, keyword_init: true)`
- Callers check `result.success?` — never infer from model state

```ruby
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
- Strong parameters: use `params.expect(user: [:email_address, :password])` (Rails 8.1), not `permit`

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
- Money stored as integer cents (`unit_price_cents`), not decimal — floating point is unsafe for money

### Views and partials

- Strict locals on every partial: `<%# locals: (invoice:) %>`
- No instance variables inside partials — ever
- Partials receive exactly what they need, nothing more
- Use `data-testid` attributes for system test selectors, not CSS classes

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

## Data model

```
Account
  - name: string, null: false

User
  - email_address: string, null: false, unique
  - password_digest: string, null: false
  - account_id: references Account, null: false

Client (belongs_to :account)
  - name: string, null: false
  - email: string
  - company_name: string
  - vat_number: string

Invoice (belongs_to :account, belongs_to :client)
  - invoice_number: string, null: false, unique (INV-0001 format)
  - issued_on: date, null: false
  - due_on: date, null: false
  - status: enum (draft, sent, paid, void), null: false, default: draft
  - notes: text

LineItem (belongs_to :invoice)
  - description: string, null: false
  - quantity: decimal, null: false
  - unit_price_cents: integer, null: false (euro cents — 5000 = €50.00)
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

---

## Build state

### What exists and works
- Registration creates Account + User in a transaction, auto-logs in
- Rails 8 built-in auth (session cookies, passwords, Current.user)
- Clients: full CRUD scoped through `Current.user.account`
- `Invoice` + `LineItem` models, migrations, associations, SQL SUM calculations, auto invoice numbers
- Invoice CRUD with nested line items form (Stimulus `nested_form` controller)
- Status transition services (`InvoiceSender`, `InvoicePaymentRecorder`, `InvoiceVoider`) + REST resource controllers
- Transition buttons in UI — only valid next actions shown
- Invoices index grouped by status with group totals
- `bin/ci`, `bin/setup`, `bin/dev` configured
- Pico CSS from CDN; strict locals on partials

### What's next
1. Print-ready invoice view (`layouts/print.html.erb` + print CSS)
2. Seed file — demo account with sample clients and invoices
3. Deploy to Render

---

## What's out of scope — do not build these

- Email delivery
- Background jobs / Solid Queue
- Multi-user account management UI
- Subscription billing
- PDF generation (print CSS is sufficient)
- Pagination
- Overdue reminders

If asked to implement any of the above, flag it and ask for confirmation first.
