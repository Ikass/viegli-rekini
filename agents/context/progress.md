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

## Known issues

- Mobile layouts overflow horizontally; the sidebar doesn't auto-hide on small viewports. Fix next: `overflow-x: hidden` + auto-hide sidebar.
- Dashboard `@overdue_invoices` mislabels draft/sent as "overdue".
- Invoice numbering uses `pluck`+`max` (O(n)) with a digit-prefix bug (`n[/\d+/]`); counter-table fix planned.
- Money/VAT totals use SQL `SUM` (float drift); line/category rounding fix planned (EN 16931 BR-CO-17).

## Next (planned)

- Mobile layout fix: `overflow-x: hidden` on the app shell + auto-hide sidebar on small viewports.
- Fix 1 — invoice-numbering counter table (numbers assigned at send, gapless).
- Fix 2 — `MoneyAmount` VO, VAT per rate/category (BR-CO-17), drop SQL `SUM`.
- README rewrite (portfolio-facing) before making the repo public.
- Backups: Litestream → R2 (interim `sqlite3 .backup`).
