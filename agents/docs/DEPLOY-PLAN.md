# Deploy Plan — Viegli-Rēķini (portfolio demo)

> **Status:** planned 2026-10-09, **executed** (live at `viegli-rekini.lv`; runbook:
> `notes/kamal-ovh-deploy.md`). Kept as the historical record of the deploy; details below
> predate the deploy and a few are now done/superseded (e.g. the repo was renamed, the
> `postgresql-client`/`libpq-dev` packages were dropped, and the counter table shipped as
> `last_number` with `prefix`/`padding` on `Account`).

**Domain:** `viegli-rekini.lv` (owned). `vieglirekini.lv` is a possible later redirect only.
**Image / registry:** `ghcr.io/ikass/viegli-rekini` (lowercase — GHCR requirement).
**Repo:** renamed `e-rekini-mvp` → `viegli-rekini` before the first deploy.

---

## Portfolio-ready cut

**IN** (a reviewer logs in via one click and creates an invoice in under a minute):

- Login + one-click **"Try the demo"**
- Dashboard
- Clients CRUD · Products CRUD
- Invoice create / edit (draft) · print view
- Status transitions (send / pay / void)
- UBL 2.1 XML download (EN 16931 profile)
- Account settings
- Seeded demo tenant with realistic Latvian data

**OUT** (explicitly, unless the audit had shown them nearly done — it did not):

- PEPPOL BIS 3.0 profile (EN 16931 is built and enough)
- Credit notes / extra document types
- Warehouse module (does not exist anywhere)
- Latvian UI translation (UI is English; only seed data is Latvian)
- Email / SMTP delivery
- PDF download (defer Chromium — print view is enough)
- Nightly reset (deferred)
- Solid Queue / Solid Cache / Solid Cable (gems not yet enabled)
- Subscription billing · pagination (already out of scope per AGENTS.md)

---

## Order of work

1. Deploy blockers → 2. Demo button + signup gate → 3. First deploy → 4. Fix 1 (numbering)
→ 5. Fix 2 (money) → 6. README rewrite → 7. Secrets history scan → 8. Go public.

---

## Tasks

### A. Deploy blockers

- **A1** *(S)* Remove `SOLID_QUEUE_IN_PUMA: true` from `config/deploy.yml`; comment out the
  `plugin :solid_queue` line in `config/puma.rb`. Without this, Puma fails to boot (the gem is
  not in the bundle). **Done:** `bin/docker-entrypoint` boots Puma in a fresh container.
- **A2** *(S)* Configure `config/deploy.yml`: real server IP, `image: ikass/viegli-rekini` (no host —
  Kamal prefixes `registry.server`), GHCR registry + `KAMAL_REGISTRY_PASSWORD` secret,
  keep `volumes: viegli_rekini_storage:/rails/storage`,
  `RAILS_MASTER_KEY`, `proxy: { ssl: true, host: viegli-rekini.lv }`. **Done:** `kamal setup` succeeds.
- **A3** *(S)* `config/environments/production.rb`: set `config.hosts = ["viegli-rekini.lv"]`,
  `config.assume_ssl = true`, `config.force_ssl = true` (exclude `/up`). **Done:** HTTPS works.
- **A4** *(S)* Hide the "Download PDF" button (deferring Chromium) and remove the
  "Forgot password?" link (no email in v1) so the UI never promises what isn't there.
  **Done:** no dead UI paths.
- **A5** *(S)* `Dockerfile`: drop the leftover `postgresql-client` / `libpq-dev` packages.

### B. Repo rename

- **B1** *(S)* Rename the GitHub repo `e-rekini-mvp` → `viegli-rekini`; update `origin`; update the
  image name in `config/deploy.yml`, `.github/workflows/ci.yml`, `README.md`, and docs.
  **Done:** `git remote -v` shows the new URL; CI/deploy reference `viegli-rekini`.

### C. Demo account

- **C1** *(S)* "Try the demo" → `DemoSessionsController#create`: `User.find_by` the demo email
  **only** (never create), `start_new_session_for`, redirect to dashboard; rate-limited; clear
  error if the demo user is missing. **Done:** one click logs in.
- **C2** *(S)* Disable public signup — gate `RegistrationsController`, remove the "Sign up" link.
- **C3** *(S)* Provision the demo tenant in prod: one-off `kamal app exec bin/rails db:seed`.
  (`seeds.rb` is idempotent — it guards on `User.find_by(demo_email)` and skips if present.)
- **C4** *(S)* Demo-user protection: block email/password change and account deletion for the demo
  user; add `rake demo:reset` that restores the seeded demo tenant. (Nightly scheduling stays
  deferred.)

### D. First deploy (OVHCloud / Kamal)

- Server: a 2 vCPU / 4 GB VPS (SQLite + single Puma is not throughput-bound). VPS already ordered
  with OVHCloud — under review; the IP is pending. Confirm the exact plan size/price in the OVH
  console once provisioned.
- DNS: A record `viegli-rekini.lv` → server IP.
- `kamal setup` then `kamal deploy`; HTTPS via Kamal proxy (Let's Encrypt).
- **Backups (interim):** `sqlite3 .backup` or `VACUUM INTO` to a safe file — **never `tar` the live
  SQLite file** (a mid-write tar can capture a corrupt snapshot).
- **Diagnose:** `kamal logs` · `kamal app exec -i bin/rails console` ·
  `kamal app exec bin/rails dbconsole`.

### E. Fix 1 — invoice numbering *(branch `fix/invoice-numbering`)*

- `invoice_sequences` table (`account_id`, `scope`, `next_number`, `prefix`, `padding`;
  unique `[account_id, scope]`).
- **Numbers assigned at send**, not at draft creation: drafts carry no number (nullable
  `invoice_number` + partial unique index); `InvoiceSender#send_invoice` allocates the number
  atomically via the counter table in the same transaction as the draft → sent flip. Keep
  "delete draft" — a draft is not an accounting document and must not consume a sequence slot.
- Allocation: a single atomic `INSERT … ON CONFLICT DO UPDATE … RETURNING` statement (SQLite
  serializes it). `before_create` (not `before_validation`) so validation failures never touch
  the counter.
- Migration seeds a `default` sequence per account from its existing max (safe on demo data).
- Tests: a concurrency guard (threads / separate connections) asserting no duplicates + no gaps —
  **documented as also passing on the old code**, because SQLite already serializes writes; plus a
  **digit-prefix regression test** (`INV24-`) that genuinely fails on the old `pluck`+`max` code.

> **CV wording:** *sequential invoice numbers via a dedicated counter table using SQLite's atomic
> upsert-increment (`INSERT…ON CONFLICT…RETURNING`) inside the same transaction as the invoice —
> not `SELECT FOR UPDATE`, which SQLite does not support.* This is a robustness refactor (O(n) →
> O(1), digit-prefix correctness, explicit intent), **not** "fixing a race" — see
> `notes/audit-findings.md`.

### F. Fix 2 — money / VAT rounding *(branch `fix/money-rounding`)*

- `MoneyAmount` value object (integer cents + round-half-up). `LineItem` + `Invoice` delegate to it.
- Delete the two SQL `SUM`/`ROUND` expressions in `Invoice` — one Ruby source of truth.
- **VAT is per rate/category, rounded once** (EN 16931 BR-CO-17): `category_tax =
  round_half_up(category_taxable × rate / 100)`; document VAT = sum of category taxes (BR-CO-14).
  Line net = `round_half_up(quantity × unit_price_cents)` (BR-CO-10). **Not** sum-of-per-line-VAT.
- `_document.html.erb` and `UblInvoiceBuilder` share the same source **and the same
  `[tax_category_code, vat_rate]` grouping** (today the HTML groups by `vat_rate` only — they can
  already diverge).
- Document the rule in `recipes/money-calculations.md` + `ARCHITECTURE.md`.
- Tests: `x.xx5` boundaries, many small lines, mixed VAT rates, 0% + exempt lines, and **HTML
  totals == UBL totals** for the same invoice; plus XSD well-formedness (Nokogiri) and assertions
  that recompute BR-CO-10/14/17 arithmetic. (Full Java/Saxon Schematron deferred to a documented
  manual step.)

### G. README *(M — before the repo goes public)*

- Portfolio-facing: what it is, stack, screenshots, live demo link, architecture highlights, an
  honest "built / next" section, local-dev instructions. Remove the render.com reference.

### H. Secrets scan *(before public)*

- `gitleaks` (or `trufflehog`) across the full git history. **Report findings only** — do not
  rewrite history without explicit approval.

### I. Go public

---

## Demo account design

- Seeded tenant "SIA Demo Uzņēmums" — Latvian reg/VAT, Swedbank IBAN, 4 clients, 6 products,
  6 invoices across all statuses (already in `db/seeds.rb`).
- Entry: one-click button on the login page. Public signup disabled.
- **No nightly reset (deferred).** Flagged risk: the demo tenant is shared and mutable, so
  reviewers can leave junk behind; data is fictional (no privacy exposure).

## Accepted risks (confirmed)

- No backups beyond the interim `sqlite3 .backup` step.
- No email — "Forgot password?" is hidden; password reset will not deliver.
- Shared, mutable demo tenant with no reset.
- GHCR auth via a **classic** personal access token with `write:packages` (fine-grained tokens are
  not accepted by GHCR); kept in the password manager / an env var, never in the repo.
- Branches `fix/invoice-numbering` and `fix/money-rounding` opened **after** the first deploy.

## Decisions still open (do not assume)

- OVH server IP (order under review) — set in `config/deploy.yml` before the first deploy.
- Whether to add the full EN 16931 Schematron validator (Java/Saxon) to CI later, vs the XSD +
  arithmetic-assertion tests now (current plan).
