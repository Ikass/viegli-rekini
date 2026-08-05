# AGENTS.md — Invoicio

Coding agent context for the Invoicio e-invoicing Rails app. Read this before making any changes.

---

## What this app is

A focused Rails 8 e-invoicing SaaS for Latvian small businesses. Multi-tenant with multi-user company accounts, multi-location support. SQLite3.

Portfolio project — code quality and architectural clarity matter as much as feature completeness.

---

## Stack

- **Rails 8.1.2** — modern idioms; `params.expect()` for strong parameters
- **SQLite3**
- **Hotwire** — Turbo + Stimulus
- **Custom vanilla CSS** (CUBE CSS) — OKLCH color tokens, Every Layout primitives, logical properties
- **Minitest** — model, service, and system tests
- **Hetzner + Kamal 2** — deployment target

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
- All queries scoped through `Current.account` — never bare `Model.find`
- Use `find_by!` — never `find_by` (silent nil is a bug waiting to happen)
- No business logic — delegate to services
- Strong parameters: use `params.expect(user: [:email_address, :password])` (Rails 8.1), not `permit`

```ruby
# Good
@invoice = Current.account.invoices.find_by!(id: params[:id])

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

## Data model

```
Identity (global — email+password, one per human)
  - email_address: string, null: false, unique
  - password_digest: string, null: false
  - has_many :users
  - has_many :accounts, through: :users

Account (tenant — one per company)
  - name: string, null: false
  - has_many :users
  - has_many :locations

User (per-company role join — bridges Identity to Account)
  - account_id: references Account, null: false
  - identity_id: references Identity, null: false
  - role: enum (admin, accountant, member), default: member
  - has_many :location_memberships

Location (company sub-unit — store, branch, warehouse)
  - account_id: references Account, null: false
  - name: string, null: false
  - prefix: string           # invoice number prefix, e.g. "RIGA"
  - invoice_counter: integer  # per-location sequential counter
  - has_many :location_memberships
  - has_many :invoices

LocationMembership (scopes which users can operate in a location)
  - location_id: references Location, null: false
  - user_id: references User, null: false
  - role: enum (viewer, operator), default: operator
  - unique index on [location_id, user_id]

Client (belongs_to :account)
  - name: string, null: false
  - email: string
  - company_name: string
  - vat_number: string
  - address, city, postal_code, country: string

Invoice (belongs_to :account, belongs_to :client, belongs_to :location)
  - invoice_number: string, null: false, unique per account
  - location_id: references Location
  - issued_on: date, null: false
  - due_on: date, null: false
  - status: enum (draft, sent, paid, void), null: false, default: draft
  - notes: text

LineItem (belongs_to :invoice)
  - account_id: references Account, null: false  # denormalised for direct tenancy scoping
  - description: string, null: false
  - quantity: decimal, null: false
  - unit_price_cents: integer, null: false (euro cents — 5000 = €50.00)
  - vat_rate: decimal, null: false, default: 0
  - position: integer (for ordering)

Product (belongs_to :account)
  - name: string, null: false
  - description: text
  - unit_price_cents: integer, null: false (euro cents)
  - vat_rate: decimal, null: false, default: 21.0
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
- `Product` model with full CRUD — virtual `default_price` attribute, cents-based storage
- Account settings page — company details, address, bank info (single edit/update page)
- Client address fields — `address`, `city`, `postal_code`, `country`
- `bin/ci`, `bin/setup`, `bin/dev` configured
- Custom CUBE CSS design system (OKLCH tokens, Every Layout primitives, forms, tables, badges, buttons)
- Print-ready invoice view (`layouts/print.html.erb` + embedded print CSS)
- Product picker (Stimulus controller + JSON endpoint) — auto-fills line item fields from product
- Seed file — demo account with sample clients, products, and invoices across all statuses
- System tests — invoice lifecycle + client CRUD (via `bin/rails test:system`)

### What's next
1. Print-ready invoice view (`layouts/print.html.erb` + print CSS)
2. Seed file — demo account with sample clients, products, and invoices across all statuses

---

---

## Architecture references

Key patterns adopted from 37signals/Basecamp Rails reference apps:

| Pattern | Source | What we adopted |
|---|---|---|
| Identity/User split | Fizzy | `Identity` (global, email+password) + `User` (per-company role join). Enables multi-company accountants. |
| URL-path tenancy | Fizzy | `AccountSlug` middleware extracts company ID from URL prefix. `Current.account` set per-request via `Current.with_account`. |
| Cascading Current attributes | Fizzy | `Current.session=` auto-sets `Current.identity`; `Current.identity=` finds `User` for `Current.account`. |
| Join code invite | Campfire/Writebook | `Account::Joinable` concern generates join codes. Invite link → registration → auto-join company. |
| Membership scoping | Campfire | `LocationMembership` join scopes which users can operate in which locations. Admin/accountant role bypasses checks. |
| AccountTenanted job concern | Fizzy | Serializes `Current.account` via GlobalID. All background jobs automatically restore tenant context. |
| Explicit account_id, no default_scope | Fizzy | `account_id` FK on every tenanted table. No hidden scoping — all queries explicitly traverse associations. |

---

## What's out of scope — do not build these

- Subscription billing
- PDF generation (print CSS is sufficient)
- Pagination

If asked to implement any of the above, flag it and ask for confirmation first.
