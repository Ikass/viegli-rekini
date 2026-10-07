# Active Context — Viegli-Rēķini

## Current work
Invoice download page (vault: Phase 1, session 8) — XML + PDF download buttons, correct MIME types.

## State
- PDF download shipped (session 6): `ferrum_pdf` gem (Ferrum/headless Chrome — no Node dep), `InvoicePdf` service (`app/services/invoice_pdf.rb`), `get :pdf` member route. Renders the shared `invoices/print` view + `print` layout via `render_to_string`, then `FerrumPdf.render_pdf`. "Download PDF" button is already on the show toolbar.
- UBL 2.1 XML download shipped (session 7): `UblInvoiceBuilder` (`app/services/ubl_invoice_builder.rb`) rendered with `Builder::XmlMarkup` (not `.xml.erb` — that does not auto-escape), `get :ubl` member route + `InvoicesController#ubl`. Targets the **EN 16931** profile, not PEPPOL BIS 3.0 (missing EndpointID/EAS data). Amounts computed in Ruby from line items.

## Next
- Invoice download page (PDF + XML buttons, MIME types) — vault session 8.
- Mark-as-sent flow (`sent_at`, VID 5-business-day deadline) — vault session 9.
- PEPPOL BIS 3.0 profile: add seller/buyer `EndpointID` + EAS `schemeID` when e-adrese data exists (Phase 6).
- Prod: add Chromium to Docker image for `ferrum_pdf` (deploy session).
- Polish round: revisit PDF `disposition: :inline` (in-tab preview) vs current forced download.
- Audit follow-ups: ✅ cross-tenant `client_id` validation fixed (model + controller) + negative cross-tenant tests added (clients, products, invoices, line_items). Remaining: define roles/permissions model.

## Decisions locked
- PDF engine: **ferrum_pdf** (Chrome-rendered HTML→PDF, no Node) over Grover/Prawn — reuses `_document` partial + print CSS, no layout drift. Chrome-in-Docker is the accepted deploy cost.
- Void = any non-void → void (number reserved); Delete = drafts only.
- `overdue` is derived (sent && due < today), not a DB status.
- Line-item selection: "Add from product" helper (Option 1) for now; combobox (Option 3) is the future target.
- VAT rate is a Product attribute; line items display it read-only today — future direction is category-select-overridable (combobox spec).
- Queue/cache: **Solid Queue + Solid Cache** is the intended future stack; gems commented out for now (issues enabling), so prod runs `:async` + `:memory_store`.
- Multi-user-per-account is near-term (to test with real users) → roles/permissions model is an upcoming decision (none exists yet).
- Litestream → Cloudflare R2 backups planned; hosting not started. Production domain: `vieglirekini.lv`.
- Invoice numbers: dedicated counter/sequence table keyed by `(account_id, scope)`; multiple sequences per account (per location + ecommerce). → `recipes/invoice-number-sequences.md`.
- Money: consolidate on Ruby BigDecimal + `MoneyAmount` value object; drop SQL `SUM` (SQLite decimals are floats). → `recipes/money-calculations.md`.
