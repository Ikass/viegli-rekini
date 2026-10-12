# Viegli-Rēķini

A focused e-invoicing SaaS for Latvian small businesses. Multi-tenant at the account level, built with Rails 8, SQLite, Hotwire and custom CUBE CSS, deployed to a single OVH VPS with Kamal 2.

**Live at [viegli-rekini.lv](https://viegli-rekini.lv)** · demo tenant: `demo@example.com` / `password`

> Deeper context lives in [`ARCHITECTURE.md`](ARCHITECTURE.md) (the *why*), [`PLAN.md`](PLAN.md) (the roadmap and regulatory background), and [`agents/docs/`](agents/docs/index.md) (contracts, recipes, and session notes).

---

## What it does

- Clients with full address, VAT number and VAT regime (standard / reverse charge / export).
- Reusable products with default price and VAT rate.
- Invoices with multiple line items and a "add from product" picker.
- Automatic subtotal / VAT / total — computed in Ruby over integer cents, VAT rounded **once per category** (EN 16931 BR-CO-17).
- Gapless, sequential invoice numbers (`INV-0001`, …) allocated from a per-account counter table **at send** — drafts carry no number, so deleting a draft never leaves a gap.
- Invoice lifecycle `draft → sent → paid`, with `void` as an escape hatch; transitions are service objects, not controller branches.
- Print-ready invoice layout (shared HTML + print CSS) and UBL 2.1 XML export for the EN 16931 semantic model.
- Account settings for company details, address, bank, and invoice-number prefix/padding.
- One-click demo tenant; public signup disabled.

---

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Language / framework | Ruby 3.4 · Rails 8.1 | `params.expect` strong parameters, modern idioms |
| Database | SQLite3 | Single file, WAL mode; Litestream → R2 backups planned |
| Auth | Rails 8 built-in | `has_secure_password` + signed cookie sessions, no Devise |
| Frontend | Hotwire (Turbo + Stimulus) | Progressive enhancement, no JS framework |
| CSS | Custom vanilla (CUBE CSS) | OKLCH tokens, Every Layout primitives, logical properties, `data-*` variants |
| Testing | Minitest + Capybara/Selenium | 162 unit/controller/service + 4 system tests |
| Deployment | Kamal 2 + OVH VPS | Docker image to GHCR, HTTPS via kamal-proxy |

---

## Architecture decisions and why

### Account-based multi-tenancy, enforced in every controller

A `Client`, `Product` and `Invoice` all belong to an `Account`. Controllers resolve records **through `Current.user.account`** — never `Invoice.all` — and foreign keys submitted in params are re-resolved against the account rather than trusted verbatim. There are tests proving one account cannot read another's data.

Single user per account today; multi-user and multi-location are the near-term target and the data model is ready for them.

### Money as integer cents, VAT rounded per category

Prices are stored as integer cents (`unit_price_cents`) — floating point is unsafe for money. `quantity` and `vat_rate` are decimal columns cast to `BigDecimal` in Ruby, so all totals are exact.

VAT is computed **once per tax category** (`round(Σ line net × rate / 100)`), not summed from per-line rounding — the difference is a cent, and EN 16931's fatal rules (BR-CO-14/17) reconcile to the cent. `Invoice#vat_breakdown` is the single source of truth that both the UBL XML and the print view read from.

### Gapless numbering via a counter table

Numbers come from `InvoiceSequence` — a `(account, scope)` row bumped by an atomic `INSERT … ON CONFLICT … RETURNING` in the **same transaction** as the status flip. Assigning at send (not at draft) means deleting a draft consumes nothing. No `MAX()` scan, no digit-parsing of a formatted number, no lock.

### Business logic lives in `app/services/`, not models or controllers

- **Models** — relationships, validations, and pure calculations (`total`, `overdue?`). No writes, no side effects.
- **Controllers** — find the record, call a service, redirect/render. One instance variable per action.
- **Services** — state transitions and anything multi-step. `InvoiceSender`, `InvoicePaymentRecorder`, `InvoiceVoider` each return a `Result` struct, so callers always know whether it succeeded.

### State transitions as REST resources

"Send this invoice" isn't a custom controller action; the transition *is* a resource:

```ruby
resources :invoice_sends, only: [:create]
resources :invoice_payments, only: [:create]
resources :invoice_voids, only: [:create]
```

Rails' seven standard actions are universally understood; a custom `POST /invoices/:id/send` is not.

### Database constraints *and* validations — both, for different reasons

Validations produce friendly error messages but can be bypassed (`update_column`). Database constraints can't. So every required column is `null: false`, every `references` has `foreign_key: true`, and the `status` enum has a check constraint as the last line of defence. Tests assert the *constraints* directly by bypassing validations.

### UBL 2.1 XML, Peppol BIS Billing 3.0

`UblInvoiceBuilder` renders the invoice as UBL 2.1 XML targeting Peppol BIS Billing 3.0 (`urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0`) — the practical format for Latvian B2G/B2B. Emits seller/buyer `cbc:EndpointID` (Latvia VAT `9939` / registration `0218` schemes), `cbc:BuyerReference` (`N/A` when blank), and requires a VAT-registered seller. Output is generated with `Builder::XmlMarkup` (auto-escaping), not an `.xml.erb` template. See `agents/docs/specs/ubl-invoice-generation.md`.

---

## Data model

```
Account
  ├── has_many :users, :clients, :products, :invoices, :invoice_sequences
  └── name, company_name, registration_number, vat_number,
      address, city, postal_code, country,
      bank_name, bank_account, bank_swift, payment_terms,
      invoice_prefix, invoice_number_padding

User        belongs_to :account
Client      belongs_to :account, has_many :invoices
Product     belongs_to :account
Invoice     belongs_to :account, :client; has_many :line_items
InvoiceSequence  belongs_to :account   # (account_id, scope) → last_number
LineItem    belongs_to :invoice
              description, quantity, unit_price_cents, vat_rate,
              tax_category_code, unit_code, position
```

---

## Invoice lifecycle

```
draft ──→ sent ──→ paid
  │          │        │
  └──────────┴────────┴──→ void
```

Invalid transitions are rejected at the service layer: no `draft → paid`, no un-voiding. `overdue` is derived (`sent? && due_on < today`), not persisted.

---

## Development

**Prerequisites:** Ruby 3.4, SQLite3.

```bash
git clone https://github.com/Ikass/viegli-rekini
cd viegli-rekini
bin/setup          # installs gems, creates + migrates + seeds the DB
bin/dev            # starts the server
```

`bin/setup` seeds a demo account with sample clients, products and invoices. Log in at `http://localhost:3000` with `demo@example.com` / `password`.

## Tests & CI

```bash
bin/ci             # rubocop → bundler-audit → importmap audit → brakeman → tests → system tests
bin/rails test     # model + service + controller tests
bin/rails test:system
```

GitHub Actions runs rubocop, Brakeman, gem/JS dependency audits, the test suite and system tests on every push.

**Manual Peppol validation** (not automated — the EC validator covers EN 16931 base rules only, not Peppol BIS 3.0): generate the XML for a *test* invoice, then check it with a Peppol-capable web validator (econnect.eu, or the EC validator at itb.ec.europa.eu/invoice). See the procedure in `agents/docs/specs/ubl-invoice-generation.md`.

## Deployment

Deployed to an OVH VPS via Kamal 2 — Docker image built locally, pushed to GHCR, pulled and booted on the server behind kamal-proxy (HTTPS via Let's Encrypt). The SQLite file lives on a persistent Docker volume. **Backups (Litestream → Cloudflare R2) are planned but not yet configured.**

---

## Deliberately not built yet

Kept out on purpose — not implied by anything here:

| Feature | Status |
|---|---|
| PEPPOL BIS 3.0 transmission / e-adrese | not built (XML export is Peppol BIS 3.0; sending via an access point not implemented) |
| Credit notes | not built |
| Email delivery (send invoice / password reset SMTP) | not built (no SMTP configured) |
| Latvian UI | English-only today |
| Multi-user / roles | single user per account |
| PDF download in production | generated via FerrumPdf, button hidden (no Chromium in the Docker image yet) |
| Subscription billing, pagination | out of scope |

---

## Learning resources

- *Sustainable Web Development with Ruby on Rails* — David Bryant Copeland
- *Agile Web Development with Rails 8* — Sam Ruby et al.
- [guides.rubyonrails.org](https://guides.rubyonrails.org)
