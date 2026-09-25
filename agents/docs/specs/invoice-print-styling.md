# Invoice Print Styling & PDF — Review Findings + Implementation Plan

**Project:** viegli-rēķini
**Scope:** `layouts/print.html.erb`, `invoices/_document.html.erb`, `blocks/invoice-doc.css`, `blocks/invoice-page.css`, and the `ferrum_pdf` (`InvoicePdf`) pipeline.
**Status:** review complete (2026-09-25); findings below are the implementation plan, prioritized.

## 0. Verdict

Strong foundations — the print architecture is genuinely good and follows most print-styling best practices. Findings are mostly *consistency/correctness* issues, not layout bugs. Top priorities: fonts (#1), money precision (#2/#3), localization (#4).

## What's already right (keep as-is)

- Single source of truth: `_document.html.erb` + `invoice-doc.css` shared between screen show page and print view (no drift).
- Real `@page` geometry (`size: A4; margin: 15mm 20mm`) with named margin boxes set to `content: none` to suppress browser headers/footers.
- Screen "A4 card" (`.print-page`) that resets to nothing under `@media print` — browser prints against true page geometry, not the fake card.
- `pt` units for type/spacing, `tabular-nums` on numeric columns, `break-inside: avoid` on rows and logical blocks.
- `print-color-adjust: exact` (+ `-webkit-` prefix); global `box-sizing: border-box` makes preview vs print line-lengths agree.

## Findings (prioritized implementation plan)

### 1. Font availability in the production PDF — ✅ DONE (2026-09-25)
`print.html.erb` used `font-family: "Helvetica Neue", Helvetica, Arial, system-ui, sans-serif`. None of these exist in the Linux Chromium Docker image, so `ferrum_pdf` fell back to DejaVu/Liberation Sans: metrics drifted from the dev preview, and Latvian diacritics depended on whatever happened to be installed.

**Resolution:** self-hosted **Atkinson Hyperlegible Next** (OFL) — Regular/Medium/Bold `woff2` in `app/assets/fonts/` (Propshaft auto-includes the directory, no `assets.paths` config needed). `@font-face` + `--print-font` token + `.invoice-doc { font-family: var(--print-font) }` live in `invoice-doc.css`; `print.html.erb` body uses `var(--print-font)`. Scoped to invoice + PDF only (app-wide UI restyle deferred to a later phase). Verified: generated PDF embeds all three weights (`AtkinsonHyperlegibleNext-Regular/Medium/Bold`), no fallback. `ferrum_pdf` `wait_for_idle` covers font loading.

> Note: `.numeric` uses `font-variant-numeric: tabular-nums`; Atkinson Hyperlegible Next's `tnum` support is unverified — re-check column alignment when #5 (locale formatting) lands.

### 2. Money formatted via float division in the view
`_document.html.erb` uses `item.unit_price_cents / 100.0` and `items.sum(&:subtotal) / 100.0`. Contradicts the locked decision ("consolidate on BigDecimal … floating point is unsafe for money"). `number_to_currency` on a Float can round-trip incorrectly. **Fix:** route printed money through the BigDecimal / `MoneyAmount` value object.

### 3. Business logic in the template
`invoice.line_items.group_by(&:vat_rate)` + `items.sum(&:subtotal)` / `items.sum(&:vat_amount)` in the view. Grouping/totals belong in the model/service. **Fix:** move to model or service; view just renders pre-computed totals.

### 4. Localization mismatch
Layout is hard-coded `lang="en"`; document is fully English ("Invoice", "Bill to", "Issued", "Due", "Total", "Notes", "Payment details"). Latvian product → printed invoice should be Latvian/localized. Content issue, but central to printed output correctness.

### 5. Locale-aware number/currency formatting
`number_to_currency(..., unit: "€")` doesn't apply LV conventions (comma decimal separator, thousands grouping). Related to #4.

### 6. Screen preview can't show multi-page invoices
`.print-page` `aspect-ratio: 210/297` + `max-height` + `overflow: auto` scrolls overflow inside a single card. Print paginates fine, but the preview hides page-break positions. **Fix (later):** multi-card preview or a "page N of M" hint.

### 7. Totals can orphan onto their own page
`break-inside: avoid` on `.totals` prevents splitting, but nothing keeps it attached to the last table row. **Fix:** `break-before: avoid` on `.totals` (or wrap totals + table).

### 8. `.header-rule` is `background` + `height: 1pt`
Fragile vs a `border-block-start`. Works because `print_background` is on; would vanish if background printing is ever toggled off. **Fix:** use `border-block-start`.

### 9. No `orphans`/`widows`, no explicit `thead { display: table-header-group }`
Chrome repeats the header by default, but it's undeclared. Minor robustness gap for multi-page tables.

### 10. No page numbers
Headers/footers deliberately suppressed, so multi-page invoices carry no "Page X of Y". Acceptable, but worth an explicit decision (tax documents often want page numbers).

### 11. Minor nits
- `.addresses` uses flexbox `gap` (modern; fine for Chrome, breaks under non-Chrome engines) — being replaced by CSS Grid anyway (below).
- `.invoice-title` uppercase + `letter-spacing: 0.5pt` leaves a trailing space with `text-align: right`.
- Page-chrome CSS inlined in the layout while tokens live in `invoice-doc.css` (split-brain, not a bug).
- `.totals` fixed `240pt` width.

## Layout change: meta under the invoice number — ✅ DONE (2026-09-25)

Moved the Issued/Due metadata out of the addresses region and into `.invoice-title` (right side, under "Invoice / No. …") so it aligns with the invoice-number block instead of floating beside "Bill to".

- `.invoice-title` now contains `h1` (Invoice) → `p` (No. …) → `<dl class="invoice-meta">` (Issued/Due).
- `.addresses` (mixed `<div>` + `<table>` grid) removed entirely; the bill-to block is now a single `.bill-to` element.
- `.invoice-meta` stays a two-column `<dl>` grid (`auto auto`, `--print-gap-sm` column gap, right-aligned values, left-aligned labels); added `margin-block-start` for spacing under the number and `text-align: left` on `dt` to counter the inherited right-align from `.invoice-title`.
- `break-inside: avoid` moved from `.addresses` to `.bill-to`.

Shared by show + print (same `_document` partial).

## Open questions

- Localization (#4/#5) — confirm the printed invoice should be Latvian, and whether to introduce i18n now or later.
