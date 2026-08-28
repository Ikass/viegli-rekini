# Active Context — Viegli-Rēķini

## Current work
PDF generation (vault: Phase 1, session 6). Plain human-readable A4 PDF download per invoice.

## State
PDF download shipped: `ferrum_pdf` gem (Ferrum/headless Chrome — no Node dep), `InvoicePdf` service (`app/services/invoice_pdf.rb`), `get :pdf` member route. Renders the shared `invoices/print` view + `print` layout via `render_to_string`, then `FerrumPdf.render_pdf` with `prefer_css_page_size`/`print_background` (geometry stays in the existing `@page` CSS). Controller test stubs `FerrumPdf.render_pdf`; real Chrome generation smoke-tested. Toolbar "Download PDF" button deferred to the download-page session.

## Next
- UBL 2.1 XML generation (`UblInvoiceBuilder`, PEPPOL BIS 3.0) — vault session 7.
- Invoice download page (PDF + XML buttons, MIME types) — vault session 8.
- Mark-as-sent flow (`sent_at`, VID 5-business-day deadline) — vault session 9.
- Prod: add Chromium to Docker image for `ferrum_pdf` (deploy session).

## Decisions locked
- PDF engine: **ferrum_pdf** (Chrome-rendered HTML→PDF, no Node) over Grover/Prawn — reuses `_document` partial + print CSS, no layout drift. Chrome-in-Docker is the accepted deploy cost.
- Void = any non-void → void (number reserved); Delete = drafts only.
- `overdue` is derived (sent && due < today), not a DB status.
- Line-item selection: "Add from product" helper (Option 1) for now; combobox (Option 3) is the future target.
- VAT rate is a Product attribute; line items display it read-only today — future direction is category-select-overridable (combobox spec).
