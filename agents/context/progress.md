# Progress — Viegli-Rēķini

## Built

- Registration (Account + User in a transaction, auto-login) on Rails 8 built-in auth (session cookies, passwords, `Current.user`).
- Clients: full CRUD scoped through `Current.user.account`; address fields, `delivery_channel`, `vat_regime`, `registration_number`, `e_adrese_id`, `iban`, `is_budget_institution`.
- Products: full CRUD — virtual `default_price` attribute, cents-based storage, UN/ECE unit + VAT category codes.
- Invoices + LineItems: nested line-items form, SQL SUM calculations (subtotal/VAT/total), auto invoice numbers (`invoice_prefix` + `invoice_number_padding`, `with_lock`).
- Status transitions as service objects (`InvoiceSender`, `InvoicePaymentRecorder`, `InvoiceVoider`) + REST resource controllers; `sent_at`/`paid_at`/`voided_at` stamped in services.
- Status-aware invoice show view (sticky toolbar, badge + number, activity strip); `Invoice#overdue?`/`display_status` (derived, not persisted); draft inline-edit, locked edits for non-drafts.
- Invoices index grouped by status with group totals; transition buttons show only valid next actions.
- Print-ready invoice view (`layouts/print.html.erb` + `invoice-doc.css`, scoped `.invoice-doc`); shared `app/views/invoices/_document.html.erb` partial.
- Account settings page (company details, address, bank info).
- Custom CUBE CSS design system (OKLCH tokens, Every Layout primitives, forms, tables, badges, buttons); card-section UI pattern across show/edit views.
- `InvoiceCodes` concern — shared `UNIT_CODES`, `TAX_CATEGORY_CODES`, `SHORT_TAX_CATEGORY_CODES`.
- Seed file (demo account: clients, products, invoices across all statuses).
- PDF generation via `ferrum_pdf` (Ferrum/headless Chrome — no Node): `InvoicePdf` service + `get :pdf` member route, rendering the shared print view to a downloadable A4 PDF.
- UBL 2.1 XML generation via `UblInvoiceBuilder` (Builder::XmlMarkup, EN 16931 profile) + `get :ubl` member route, downloadable per invoice. See `agents/docs/specs/ubl-invoice-generation.md`.
- `bin/ci`, `bin/setup`, `bin/dev`; system tests (invoice lifecycle + client CRUD).

## Known issues

- Dashboard `@overdue_invoices` mislabels draft/sent as "overdue" — revisit with derived-overdue work.
- PEPPOL/UBL not built yet (was stubbed as a broken `<# if %>` block, now removed).

## Next (planned)

- Invoice download page (PDF + XML + print), mark-as-sent, partial-payment UI (deferred toolbar stubs).
- PEPPOL BIS 3.0 profile (EndpointID/EAS) once e-adrese data exists (Phase 6).
- Phase 1B tenancy (Identity/User split, URL-path tenancy, `Location`/`LocationMembership`) — see `ARCHITECTURE.md`.
- Line-item combobox (select-or-create) — see `agents/docs/specs/line-item-selection-options.md`.
- Prod: install Chromium in Docker image (`ferrum_pdf` `browser_path`/`no-sandbox`) — deploy session.
