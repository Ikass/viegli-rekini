# ARCHITECTURE.md

Read this before touching code on a non-trivial change. `AGENTS.md` tells you the line-level
rules (naming, migrations, view structure). This file tells you *why* the app is shaped the way
it is, so a new feature extends the shape instead of working around it.

If you're an agent picking up a task: **AGENTS.md → this file → the relevant file in
`agents/docs/contracts/` → the closest existing implementation → then write code.**

---

## The shape in one paragraph

Viegli-Rēķini is multi-tenant at the `Account` level (one company). Today that tenancy is
single-level: a `User` `belongs_to` one `Account`, and every lookup is scoped through
`Current.user.account`. There is no `default_scope`-based scoping in the tenancy boundary itself
(`Client`'s `default_scope` is only an alphabetical sort, not a tenant filter) — every query
traverses the account explicitly, so an agent reading a controller can see the tenancy boundary
without having to know a hidden global is in play.

## Tenancy model

```
Account  (the tenant — one per company)
   └─ User  (email + password_digest, belongs_to one account)
```

`Current` is a request-scoped `ActiveSupport::CurrentAttributes` that holds `session` and
delegates `user`. Controllers derive the account as `Current.user.account` — there is no
`Current.account` yet. See `agents/docs/contracts/tenancy.md` for the exact pattern to follow
when adding a new tenant-owned resource — don't improvise a new scoping style.

## Request lifecycle

1. Session resolves `Current.user` (Rails 8 built-in session auth).
2. Controllers scope every lookup through `Current.user.account` (or an association under it),
   never `Model.find`.
3. Controllers stay thin — one instance variable per action, no branching business logic.
4. State-changing logic lives in a service object, one per transition, returning a `Result`
   struct. Controllers check `result.success?`, never infer state from the model afterward.
5. Views receive exactly what they need via strict locals — no reaching into instance
   variables inside partials.

## Where a decision belongs

| Question | Answer |
|---|---|
| Is this a tenancy boundary question? | `agents/docs/contracts/tenancy.md` |
| Is this a status transition? | New service object in `app/services/`, see `agents/docs/contracts/service-objects.md` |
| Is this a calculation (totals, VAT)? | `Invoice` model method — pure, no DB writes |
| Does this need a record of who-did-what-when? | `agents/docs/recipes/audit-events.md` |
| Does this gate a feature behind a plan/tier? | `agents/docs/recipes/entitlements-lite.md` — don't hand-roll a new ad-hoc check |
| Is this HTTP orchestration only? | Controller — thin, delegates to a service |

## What's deliberately not built yet

These are absent on purpose, not by oversight — don't add them speculatively:

- **Subscription billing / Stripe** — no paying customers yet. When this becomes real, read
  `agents/docs/recipes/entitlements-lite.md` first; it's designed to grow into a Pay/Stripe
  boundary later without a rewrite.
- **Pagination** — dataset sizes don't warrant it yet.
- **A generic "policy" layer (Pundit-style)** — roles are simple enough (admin / accountant /
  member, viewer / operator at location level) that explicit checks in services are more legible
  than a policy-object layer would be at this size. Revisit only if role logic starts repeating
  across more than ~4 places.

## Compliance context

Latvian e-invoicing legal requirements (Grāmatvedības likums, MK Nr. 749/2025, PEPPOL BIS 3.0 /
UBL 2.1) live in the Obsidian vault, not here — see `lv-invoice-legal-requirements.md` and
`viegli-rekini-invoice-generation-architecture.md` under
`01.Projects/Rails/viegli-rekini/`. This file only covers *code* architecture.

## Data model

The current schema (source of truth: `db/schema.rb`):

```
Account  (tenant — one per company)
  - name: string, null: false
  - company_name, registration_number, vat_number: string
  - address, city, postal_code, country: string
  - bank_name, bank_account, bank_swift: string
  - payment_terms: text
  - invoice_prefix: string, default: "INV"
  - invoice_number_padding: integer, default: 4
  - has_many :users, :clients, :products, :invoices

User (belongs_to :account)
  - email_address: string, null: false, unique
  - password_digest: string, null: false  (has_secure_password)
  - has_many :sessions

Session (belongs_to :user)
  - ip_address, user_agent: string

Client (belongs_to :account)
  - name: string, null: false
  - email, company_name, vat_number, registration_number: string
  - address, city, postal_code, country, country_code: string
  - e_adrese_id, iban: string
  - is_budget_institution: boolean
  - delivery_channel: enum (email, e_adrese), default: email
  - vat_regime: enum (standard, reverse_charge, export), default: standard
  - has_many :invoices
  - default_scope { order(:name) }  # alphabetical sort only, not a tenant filter

Invoice (belongs_to :account, :client)
  - invoice_number: string, null: false, unique per account (index [account_id, invoice_number])
  - issued_on: date, null: false
  - due_on: date, null: false
  - status: enum (draft, sent, paid, void), null: false, default: draft
  - sent_at, paid_at, voided_at: datetime  # set by transition services
  - notes: text
  - has_many :line_items

LineItem (belongs_to :invoice)
  - description: string, null: false
  - quantity: decimal, null: false
  - unit_code: string, null: false, default: "C62"  # UN/ECE 20 (InvoiceCodes concern)
  - unit_price_cents: integer, null: false (euro cents — 5000 = €50.00)
  - tax_category_code: string, null: false, default: "S"  # UNCL 5305 (InvoiceCodes concern)
  - vat_rate: decimal, null: false, default: 0
  - position: integer (for ordering)

Product (belongs_to :account)
  - name: string, null: false
  - description: text
  - default_price_cents: integer, null: false (euro cents)
  - default_vat_rate: decimal, null: false, default: 21.0
  - unit_code: string, null: false, default: "C62"
  - tax_category_code: string, null: false, default: "S"
```

**Calculated on Invoice (no DB columns):**
- `subtotal` — sum of line item subtotals
- `vat_total` — sum of line item VAT amounts
- `total` — subtotal + vat_total

**Derived (not persisted):**
- `overdue?` — `sent? && due_on < Date.current`; surfaced via `display_status`.

## Status lifecycle

```
draft → sent → paid
  ↓       ↓      ↓
void    void   void
```

Invalid transitions raise an error — they do not silently fail. Each transition is a separate
service object, and each stamps its timestamp:

- `InvoiceSender#send_invoice(invoice:)` — draft → sent, sets `sent_at`
- `InvoicePaymentRecorder#record_payment(invoice:)` — sent → paid, sets `paid_at`
- `InvoiceVoider#void_invoice(invoice:)` — any non-void → void, sets `voided_at`

## Phase 1B target (not yet built)

The multi-tenancy architecture in `PLAN.md` (§Multi-tenancy: Identity/User split) is the target
shape, not the current one. Do not write code against it yet:

- **Identity/User split** — a global `Identity` (email+password, one per human) plus a `User`
  per-company role join, enabling one login across multiple accounts.
- **URL-path tenancy** — `AccountSlug` middleware extracts the company from the URL path and sets
  `Current.account`.
- **`Location` / `LocationMembership`** — sub-tenant branches/stores with per-location invoice
  counters and membership-scoped access.
- **Denormalised `account_id` on `line_items`** for direct tenancy scoping.

Until Phase 1B lands, tenancy is the single-level `User → Account` shape documented above.
