# Progress — Viegli-Rēķini

## Done
- Registration (Account + User in a transaction, auto-login), Rails 8 built-in auth.
- Clients, Products, Invoices full CRUD — tenancy-scoped, nested line items, product picker.
- Status transitions (send/pay/void) as service objects; invoices index grouped by status.
- Auto invoice numbers (per-account prefix/padding, `with_lock` atomicity).
- UN/ECE unit codes + VAT category codes (Stimulus auto-rate).
- Print-ready invoice view (HTML + print CSS).
- Card-section UI pattern across show/edit views.
- `bin/ci`, `bin/setup`, `bin/dev`; system tests (lifecycle + client CRUD).
- (2026-08-27) Print bug fixed; shared `_document` partial + `invoice-doc.css` extracted.

## Known issues
- Dashboard `@overdue_invoices` mislabels draft/sent as "overdue" — revisit in Phase 2 derived-overdue work.
- PEPPOL/UBL not built yet (was stubbed as a broken `<# if %>` block, now removed).

## Next (planned)
- Invoice Show View Redesign phases 2–6 (see active_context.md).
- Then: PDF generation, UBL 2.1 XML, download page, mark-as-sent, Phase 1B tenancy.
