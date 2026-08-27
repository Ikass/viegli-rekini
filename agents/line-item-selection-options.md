# Line Item Selection & Editing — Options & Decisions

**Project:** viegli-rēķini
**Status:** Decided (Option 1 implemented) — Option 3 (combobox) documented as the future target
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
| 3. Searchable autocomplete | One field searches products + accepts free text | Best UX | Most work (custom Stimulus autocomplete) | **Future target — spec below** |

## Combobox spec (future — Option 3)

The standard "select-or-create" pattern (HubSpot line-item editor, FreshBooks, Wave,
Notion, Linear, GitHub labels): **one unified combobox, not a mode toggle** — no
"From catalog / Custom" decision before the user starts typing.

### Behavior

1. The **Description field itself is the search field**. Typing shows a dropdown of catalog matches (fuzzy match on name/description).
2. The last dropdown item is always **`+ Add "…" as a new item`** — free text, no catalog required.
3. Selecting a catalog match **prefills** unit price + VAT. It is a prefill, not a reference — the row remains independently editable afterward.
4. Selecting "+ Add" keeps the typed text; price/VAT are left for manual entry.

### Handling custom items

- A custom line item is **never locked to the catalog**. Catalog-sourced and custom rows both become their own independent record on the invoice once added.
- Optional **"Save to my product/service list for next time"** checkbox on custom items (default unchecked). Never mandatory — catalog growth is a byproduct, not a prerequisite.

### Data model

- `LineItem` already stores its own `description` / `unit_price_cents` / `vat_rate` at the time it's added — no live product lookup, so a sent invoice stays immutable if the catalog changes. **This is already satisfied**; no change required.
- Future (only if "save back to catalog" / provenance is wanted): an optional **nullable `product_id`** on `LineItem`. Not required for the combobox itself.

### VAT handling (future)

Move from read-only to **category-select-overridable**:

- VAT is a `<select>` of the pre-defined categories (`S`/`S12`/`S5`/`Z`/`E`/`AE`/`G`), pre-filled from the product but overridable per line item.
- The rate is always **derived from the category** (never a free-typed number).
- This reconciles compliance (only valid categories, no mismatched rates) with the need for custom/one-off items at a non-standard VAT.

### Staged implementation

- **Stage 1 — Core combobox**: embed the account's product catalog in the form as a Stimulus value (client-side fuzzy filter; no search endpoint — small-business catalogs fit in-page). Keyboard ↑/↓ + Enter to select/add. Replaces the "Add from product" dropdown.
- **Stage 2 — Catalog growth & relevance**: optional "save to catalog" (needs a create-product-from-invoice flow); recency/frequency ordering (needs usage tracking, e.g. `last_used_at` on `Product`).
- **Stage 3 — Flow & touch**: Enter advances focus to the next row's description; mobile full-width dropdown with large tap targets.

## VAT handling (current, implemented)

- VAT rate is set on each **Product** (via its VAT category, which auto-fills the rate).
- Line items only **display** the rate (read-only); they no longer expose an editable VAT category/rate.
- The JS `vat-category` controller remains for the product form only.
- (Future: see "Combobox spec — VAT handling" above — category-select-overridable.)

## Known limitations to revisit

- Custom line items always default to standard VAT (`S`/21%) and unit `C62` — a custom item can't be zero-rated (export/reverse charge) without creating a product first. *(Addressed by the future category-select VAT.)*
- Line-item "total" per row is not shown in the editor (only the section totals); a live totals column would need JS.
- The product list isn't searchable yet — as product counts grow, the combobox (Option 3) becomes the upgrade path.
