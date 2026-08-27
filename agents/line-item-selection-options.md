# Line Item Selection & Editing — Options & Decisions

**Project:** viegli-rēķini
**Status:** Decided (Option 1) — revisit for Option 3 in the future
**Updated:** 2026-08-27

## Current decision (implemented)

- **"Add from product"** is a dropdown beside "Add line item". Picking a product appends a pre-filled row.
- A row's editable fields are: **description**, **quantity**, **unit price**.
- **Unit** and **VAT** are read-only: they come from the product (unit code + tax category/rate) and are shown as muted text with hidden form fields.
- Custom (non-product) line items: "Add line item" appends a blank row defaulting to unit `C62` (piece) and standard VAT `21% (S)`.

## Options considered

| Option | Behavior | Pros | Cons | Status |
|---|---|---|---|---|
| 1. "Add from product" helper | Row = editable description/qty/price; product picker is a separate dropdown that appends a pre-filled row | Description stays editable for ad-hoc tweaks; no duplication in the row | Product fill is a two-step | **Current** |
| 2. Select-only product/service | First field is a product `<select>` with a "Custom…" option; picking fills the row, "Custom…" reveals a text input | Single field, no duplication | Can't tweak description on product items; needs "custom" fallback | Not chosen |
| 3. Searchable autocomplete | One field searches products + accepts free text | Best UX | Most work (custom Stimulus autocomplete) | **Long-term target** |

## VAT handling

- VAT rate is set on each **Product** (via its VAT category, which auto-fills the rate).
- Line items only **display** the rate (read-only); they no longer expose an editable VAT category/rate.
- The JS `vat-category` controller remains for the product form only.

## Known limitations to revisit

- Custom line items always default to standard VAT (`S`/21%) and unit `C62` — a custom item can't be zero-rated (export/reverse charge) without creating a product first.
- Line-item "total" per row is not shown in the editor (only the section totals); a live totals column would need JS.
- The product list isn't searchable yet — as product counts grow, Option 3 (autocomplete) becomes the upgrade path.
