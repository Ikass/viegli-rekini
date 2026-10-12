# Progress — Viegli-Rēķini

## Built

- Registration (Account + User in a transaction, auto-login) on Rails 8 built-in auth.
- Clients / Products / Invoices + LineItems: full CRUD scoped through `Current.user.account`.
- Status transitions as service objects + REST resource controllers; `sent_at`/`paid_at`/`voided_at`.
- Status-aware invoice show (sticky toolbar, badge, activity strip); `Invoice#overdue?` derived; draft inline-edit; non-draft locked.
- Print view (`layouts/print.html.erb` + `invoice-doc.css`); shared `_document.html.erb`.
- UBL 2.1 XML (`UblInvoiceBuilder`, EN 16931 profile) + PDF (`ferrum_pdf`) — PDF button hidden (no Chromium in Docker).
- CUBE CSS design system (OKLCH tokens, Every Layout primitives, card-section pattern).
- `bin/ci`, `bin/setup`, `bin/dev`; system tests.
- **Deployed live** to OVH VPS via Kamal — `viegli-rekini.lv`, HTTPS, persistent `/rails/storage` volume. Runbook: `agents/docs/notes/kamal-ovh-deploy.md`.
- One-click "Try the demo" + public signup disabled; demo-user protection; `rake demo:reset`.
- Brand renamed to Viegli-Rēķini (module `ViegliRekini`); auth pages refactored off inline styles.
- Dark-mode invoice fix (`.invoice-doc` forced to white paper).
- Secrets scan (gitleaks) — clean.
- Mobile/UI polish: sidebar → bottom tab bar < 40rem, responsive tables (`grid-template-columns:
  minmax(0,1fr)` kills page-level overflow), icon-only brand, `xs` button size, back-link
  alignment, overflow-menu auto-close (Stimulus).
- Repo + local folder renamed to `viegli-rekini`.
- VAT/money correctness: per-category VAT (EN 16931 BR-CO-17), Ruby/BigDecimal totals (no SQL
  `SUM`), line net rounds half-up; `Invoice#vat_breakdown` single source for UBL + print.
- Invoice numbering: dedicated `InvoiceSequence` counter table (atomic upsert `RETURNING`), numbers
  assigned **at send** (drafts unnumbered → gapless), O(1), no digit-prefix parsing.
- System-test hardening: `send_invoice_via_js` replaces the flaky `click_button "Send invoice"`
  (Turbo interception), status asserted via `data-status`; GitHub CI fully green.
- Portfolio-facing README rewrite (live product framing, honest "not built" table).
- Cloudflare Web Analytics on the public login page only (`/session/new`); strategy + follow-ups in
  `agents/docs/ANALYTICS-PLAN.md`.

## Known issues

- Dashboard `@overdue_invoices` mislabels draft/sent as "overdue".

## Next (planned)

- `MoneyAmount` VO (optional; per-category VAT + Ruby sum done).
- Backups: Litestream → R2 (interim `sqlite3 .backup`).
- Uptime check on `/up`; Ahoy + Blazer for in-app events (see `agents/docs/ANALYTICS-PLAN.md`).
- Make the repo public.
