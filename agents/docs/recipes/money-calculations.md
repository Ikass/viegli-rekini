# Money calculations (recipe)

> **Status:** decided direction. **As built (2026-10-11):** the consolidation and per-category
> VAT rounding shipped (see `notes/audit-findings.md` §2/§5) — `Invoice` computes totals in Ruby
> (`vat_breakdown`, `subtotal`, `vat_total`, `total`), and `UblInvoiceBuilder` + `_document.html.erb`
> read from it. The `MoneyAmount` value object (item 3 below) is still deferred.

## Why this exists

Invoice totals are computed twice, two different ways, and they can disagree by a cent.

**Path 1 — `Invoice`, in SQL** (`app/models/invoice.rb`):

```ruby
def subtotal;  line_items.sum("quantity * unit_price_cents") end
def vat_total; line_items.sum("ROUND(quantity * unit_price_cents * vat_rate / 100)") end
def total;     subtotal + vat_total end
```

**Path 2 — `LineItem`, in Ruby** (`app/models/line_item.rb`):

```ruby
def subtotal;   (quantity * unit_price_cents).to_i end
def vat_amount; (subtotal * vat_rate / 100).round end
def total;      subtotal + vat_amount end
```

`quantity` (`decimal(10,2)`) and `vat_rate` (`decimal(5,2)`) are decimal columns, but **SQLite has
no true decimal type** — it stores them with NUMERIC affinity as 64-bit floats. So Path 1 is
floating-point arithmetic with an *unrounded* `subtotal` (`0.1 × 1234` → `123.40000000000002`
cents), while Path 2 is exact BigDecimal.

The print document mixes them: per-line `item.total` and per-rate `items.sum(&:subtotal)` /
`items.sum(&:vat_amount)` are Ruby (Path 2), but the grand total uses `invoice.total` (Path 1).
`number_to_currency` rounds at render time, so display usually looks right — but the underlying
cent values can drift by ±1 (round-each-line-then-sum vs sum-then-round), which is exactly where
an e-invoice's VAT breakdown must reconcile.

## The decision

**Consolidate on the Ruby BigDecimal path (Path 2), accepting that it is not the most performant
choice.** This app is not throughput-bound — an invoice has ~1–20 line items, so per-line Ruby
arithmetic is irrelevant performance-wise; SQL `SUM` only wins at thousands of rows, which an
invoice never has. Exactness beats a micro-optimisation that isn't needed.

Concretely:

1. **One source of truth.** Make `Invoice#subtotal/vat_total/total` compute from `line_items` in
   Ruby (or delegate to the value object below), and delete the SQL `SUM`/`ROUND` versions. Update
   the stale "calculations happen in the database" comment on the model.
2. **Per-rate grouping in Ruby.** The per-VAT-rate breakdown (`_document.html.erb`) and the grand
   total must be derived from the *same* line-level values, so `breakdown.sum == total` by
   construction — no independent round-of-sum vs sum-of-round paths.
3. **`MoneyAmount` value object**:
   owns cents as `Integer`, `+`, `-`, `*`, rounding, and `to_s`/formatting. Both `Invoice` and
   `LineItem` delegate to it so the `n / 100.0` and `number_to_currency` calls stop scattering
   through views.
4. **Keep cents as integers everywhere.** The value object's internal unit is integer cents; only
   its `to_s` produces a decimal string. Never reintroduce float for money.

## When this becomes relevant

Building UBL 2.1 / PEPPOL XML (the `<cac:TaxTotal>` breakdown must add up to the
`<cbc:TaxInclusiveAmount>` to the cent). Until then, display rounding masks the drift and the
dual path is harmless in practice.
