# Learning Log — Viegli-Rēķini

A curated guide to *how and why* this app was built. Grows over time: durable decisions and
lessons from `agents/logs/` get promoted here (by `/sync`), so this
stays a readable trail of the architectural choices rather than a raw journal.

Read this alongside `ARCHITECTURE.md` — that file explains the *current* shape; this one explains
*how we got here* and what to carry into the next Rails app.

> Seeded 2026-09-16 from the first build sessions.

---

## Architecture & services

### One service object per state transition
Each status transition is a separate service (`InvoiceSender`, `InvoicePaymentRecorder`,
`InvoiceVoider`) returning a `Result` struct; controllers check `result.success?` and never
infer state from the model afterward.
**Why it matters:** the transition, its rules, and its timestamp live in one place. Extend the
state machine by adding a service, not by growing controller branches.

### Derived status over persisted enum
`overdue` is computed (`sent? && due_on < today`), not a DB column. The DB check constraint stays
minimal (draft/sent/paid/void).
**Why it matters:** don't persist what can be derived — it avoids staleness bugs and keeps the
enum constrained. Persist the facts (status, timestamps); derive the presentation.

### Fold orchestration into the existing action
"Send invoice" submits the form with `commit=send`, handled in `update`, which calls
`InvoiceSender` — not a JS two-step.
**Why it matters:** the service stays the single transition authority; the button just picks
which commit path to take.

## Data model

### Money as integer cents
`unit_price_cents`, `default_price_cents` — integers, never floats or decimals.
**Why it matters:** floating point is unsafe for money. Integer cents keep arithmetic exact;
format at the view layer only.

### Sum money in Ruby, not SQL
SQLite has no true decimal type (it stores decimals as 64-bit floats), and `Invoice#subtotal` used
SQL `SUM`. The UBL builder sums `LineItem` values in Ruby instead.
**Why it matters:** when output must reconcile to the cent (an e-invoice VAT breakdown), do the
arithmetic in Ruby/BigDecimal — skip SQL `SUM` on decimal columns.

### Denormalized line items — prefill, not reference
A `LineItem` copies description/price/VAT at creation; it doesn't reference the `Product`. The
"add from product" helper prefills, it doesn't link.
**Why it matters:** an invoice is a historical document — it must stay correct even if the
catalog changes later. Copy-at-write gives immutability for free; the future combobox is a UI
change plus an optional `product_id`, not a schema rework.

## Testing

### Minitest 6 dropped `minitest/mock`
`Object#stub` is unavailable on Minitest 6. Stub with `define_singleton_method` + `ensure
remove_method` instead.
**Why it matters:** a common Rails testing idiom silently breaks on Minitest 6 — know the
replacement before you hit it mid-session.

### `data-controller` selector needs word-match
`[data-controller='product-picker']` never matched because the real value was
`product-picker vat-category`. Use `~=` word-match.
**Why it matters:** Stimulus elements can carry multiple controllers; exact-match selectors
silently target nothing.

### `form.submit()` skips Turbo's interceptor in system tests
Turbo's form interceptor listens for the `submit` event, but the legacy `HTMLFormElement#submit()`
doesn't fire it — so JS `form.submit()` navigates natively and is reliable in headless Chrome,
where `click_button` + Turbo fetch flake. Also: don't assert on CSS-`text-transform`ed text
(`assert_text "SENT"` when the DOM says "Sent"); assert on a `data-status` attribute instead.
**Why it matters:** in Rails system tests, submit forms via `form.submit()` in `execute_script`
(with any `commit` param injected as a hidden input), and drive assertions off real attributes
rather than CSS-presentation text.

## Frontend & CSS

### Unlayered CSS beats the layered design system
The print CSS was unlayered inline, which wins over `@layer` styles. Scoping it under
`.invoice-doc` in the `blocks` layer fixed the leak.
**Why it matters:** unlayered CSS always beats layered CSS. Keep *all* page/component styles
layered and scoped, or you'll fight invisible specificity.

### `<select>` min-width inflates tables
Long option text widened an editable table to 1007px; `table-layout: fixed` + explicit widths
tamed it.
**Why it matters:** form controls have intrinsic min-content sizing. In editable tables, fix the
layout and render read-only values as text, not controls.

### `<template>` foster-parenting
The HTML parser moves `<template>` out of `<tbody>`. Keep the row template outside the table;
`insertAdjacentHTML` on the `<tbody>` still parses `<tr>`.
**Why it matters:** nested-form-row patterns break silently if the template lives inside the
table — put it outside.

## PDF generation

### `ferrum_pdf` over Grover/Prawn
Chrome-rendered HTML→PDF via Ferrum, no Node dependency; reuses the shared print view + print
CSS, so no layout drift. Trade-off: Chromium in the prod Docker image.
**Why it matters:** generating PDFs from the same HTML/CSS the user sees avoids a second
rendering path. Accept the container-size cost instead of a separate template engine.

## E-invoicing / XML

### Generate XML with a builder, not `.xml.erb`
Rails auto-escapes only `.html.erb`; `.xml.erb` does not. `UblInvoiceBuilder` uses
`Builder::XmlMarkup`, which escapes text and attributes.
**Why it matters:** unescaped `&`/`<` in user data silently produces malformed XML. Use a
generator that escapes by construction for any structured-output format.

### EN 16931 first, PEPPOL profile when endpoint data exists
> **Superseded (2026-10-12):** the app now targets Peppol BIS Billing 3.0 — `CustomizationID
> urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0`, with seller/buyer
> `cbc:EndpointID` (Latvia VAT `9939` / registration `0218`). See
> `agents/docs/specs/ubl-invoice-generation.md`.

Output targets `CustomizationID urn:cen.eu:en16931:2017`. PEPPOL BIS 3.0 makes seller/buyer
`cbc:EndpointID` + EAS `@schemeID` mandatory (fatal rule `PEPPOL-EN16931-R010`).
**Why it matters:** don't emit a profile your data can't satisfy. Ship the achievable profile;
add the stricter one when the data exists.

### Round VAT once per category, not per line
EN 16931 (BR-CO-17/14) defines VAT per category: `round(Σ line net × rate / 100)`, summed across
categories. Summing per-line-rounded VAT drifts a cent, which a validator rejects.
**Why it matters:** structured e-invoices reconcile the VAT breakdown to the cent. Round at the
aggregate (category) level and make that breakdown the single source both the XML and the print
view read from.

### Counter table for gapless, atomic numbering
Sequential invoice numbers come from a dedicated counter table with an atomic
`INSERT … ON CONFLICT DO UPDATE … RETURNING`, bumped in the same transaction as the invoice save
(and only at issue, so a deleted draft never leaves a gap).
**Why it matters:** don't derive the next number from `MAX(existing)` — that's O(n), fragile under
concurrency, and parsing digits out of a formatted number is a bug waiting to happen. A single
atomic statement is correct by construction.

### Rails `select_value` breaks UPSERT `RETURNING` on SQLite
`select_value`/`select_all` mis-handle an `INSERT … ON CONFLICT … RETURNING` on the SQLite adapter
— they return the stale value and don't apply the increment. `exec_query` does it correctly.
**Why it matters:** before trusting that a raw SQL statement returns what the driver returns, test
it through the adapter you're actually calling; the query-cache/write-detection path can silently
divert write statements.

## Monitoring & error tracking

### Error tracking with a PII scrubber, not raw capture
Sentry (EU region) configured error-tracking-only: `send_default_pii = false`,
`traces_sample_rate = 0.0`, and a `before_send` hook (`ScrubInvoiceData`) that strips invoice and
contact PII — IBAN, VAT number, client names — from `extra`, breadcrumbs, query strings, and
messages.
**Why it matters:** an error tracker is a third party, and GDPR means the event it receives must
not carry customer invoice data. Ship error tracking with PII off by default plus an explicit
scrubber, and leave tracing off until it's actually needed (traces can carry SQL and params).
