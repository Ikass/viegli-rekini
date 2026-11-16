# i18n audit — ViegliRēķini

Written 2026-11-16 as i18n-plan Phase 0. Counts are approximate; the point is scope,
not precision. "Hardcoded" = a user-visible English string not yet in `config/locales/`.

## Open questions (from the plan) — answers

1. **Are UI strings in locale files or hardcoded?** Mostly hardcoded. Only
   `dashboards/show.html.erb` uses `t()` (8 keys already in `en.yml`, from before this
   effort). Everything else — views, controllers (flash), models (validations + enum
   labels), mailer — is hardcoded English.
2. **PDF/print rendering?** `invoices/print.html.erb` renders `_document.html.erb` inside
   `layouts/print.html.erb` (A4 `@page`, Atkinson Hyperlegible Next via `--print-font`).
   PDF = `InvoicePdf` → `FerrumPdf.render_pdf(html: …)`, using that same print HTML.
3. **Mailers?** One: `PasswordsMailer#reset` (subject "Reset your password") + HTML/text
   templates. No invoice email yet (deferred).
4. **Public pages served by Rails?** Yes. Landing (done, `landing.{lv,en}.yml`), login
   (`sessions/new`), password reset (`passwords/*`), sign-up (redirect stub). All `auth`
   layout.

## String inventory by area

| Area | ~count | Where |
|---|---|---|
| Layout / nav | 10 | `layouts/application.html.erb` (Account, Sign out, Sign in, Dashboard, Invoices, Clients, Products) |
| Footer | 1 | `shared/_footer.html.erb` ("Simple invoicing for small businesses") |
| Auth | 20 | `sessions/new`, `passwords/new`, `passwords/edit` |
| Dashboard | 8 | already `t()` in `en.yml` |
| Clients | 40 | `clients/_form`, `index`, `show`, `new`, `edit` |
| Products | 25 | `products/_form`, `index`, `show`, `new`, `edit` |
| Invoices | 50 | `invoices/_form`, `index`, `_table`, `show`, `new`, `_line_item_fields` |
| Invoice document | 25 | `invoices/_document.html.erb` (Phase 5 → `documents.*` namespace) |
| Line items | 10 | `line_items/_form`, `new`, `edit` |
| Settings (account) | 20 | `accounts/edit` |
| Flash messages | 30 | all controllers |
| Validation messages | 15 | models (mostly Rails defaults → `rails-i18n` covers LV) |
| Enum/status labels | 25 | `InvoiceCodes::UNIT_CODES` (12), `TAX_CATEGORY_CODES` (7), `SHORT_TAX_CATEGORY_CODES` (7); `Invoice.status` (draft/sent/paid/void + derived "overdue"); `Client.delivery_channel` (2), `Client.vat_regime` (3) |
| Mailer | 5 | `passwords_mailer` + subject |
| Helper | 1 | `invoice_number_or_draft` → "Draft" |

Rough total ≈ **270 hardcoded strings**.

## Date / number / money formatting

- **Money:** `number_to_currency(x / 100.0, unit: "€")` — in `products/*`, `invoices/*`
  (form, table, totals), and `_document.html.erb`. Default `:en` format
  (`€1,234.56`); LV needs `rails-i18n` for `1 234,56 €`.
- **Dates:** `Date`/`Time` values rendered directly (`invoice.issued_on`,
  `@invoice.created_at.to_date`) — default format. Mailer uses
  `distance_of_time_in_words` (LV via `rails-i18n`).
- **Percentages:** `vat_rate_percentage` helper (`"21%"`), locale-neutral.

## PDF / print / XML

- **Print + PDF:** `_document.html.erb` holds every document label (Invoice, No., Issued,
  Due, Bill to, Description, Qty, Unit price, VAT, Total, Taxable, Payment details, Notes,
  the compliance/signature footer). These move to `documents.{lv,en}.yml` in Phase 5.
- **XML:** `UblInvoiceBuilder` — **no user-visible labels**, only structural codes
  (UNCL/UN/ISO) and free-text fields (`description`, `notes`, `party names`). Already
  language-independent; Phase 5 only needs the "identical XML under both locales" test.
- **Free text not translated:** item descriptions, notes, party names, payment terms.

## Sequencing note (deviation from the plan's literal Phase 1)

The plan sets `default_locale = :lv` in Phase 1 and "raise on missing" in dev/test, but
that only works once the app is translated (Phase 3). Since we're extracting (Phase 2) and
translating (Phase 3) *after* Phase 1, `default_locale` must stay `:en` through Phase 2,
then flip to `:lv` in Phase 3 once `lv/*.yml` exists. The `:lv → :en` fallback is a
production safety net only (as the plan says), not a dev/test crutch.
