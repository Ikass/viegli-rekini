# Spec: UBL 2.1 e-invoice generation

**Status:** built (2026-10-07) — Phase 1, session 7.
**Scope:** `UblInvoiceBuilder`, the `get :ubl` member route, and the `InvoicesController#ubl` action.

## What this does

Renders an `Invoice` as a UBL 2.1 XML document for the EN 16931 semantic model — the
machine-readable counterpart to the human-readable PDF (`InvoicePdf`).

## Shape

`UblInvoiceBuilder` is a **pure renderer**, not a state transition, so it follows the `InvoicePdf`
shape (`new(invoice)` + a public reader + `#filename`) rather than the `Result`-struct shape in
`contracts/service-objects.md`. Callers get a string and a filename; nothing is persisted.

## Decisions

1. **Profile = EN 16931, not PEPPOL BIS 3.0 (for now).** PEPPOL BIS 3.0 requires a seller and
   buyer `cbc:EndpointID` with an EAS `@schemeID`, and *fatal* rule `PEPPOL-EN16931-R010` rejects
   the document when it is missing. The app has no seller electronic address and the buyer's
   (`client.e_adrese_id`) is optional. So the first release targets plain EN 16931
   (`CustomizationID = urn:cen.eu:en16931:2017`), which is valid and validate-able. Switch
   `CustomizationID`/`ProfileID` and add `EndpointID` when e-adrese/endpoint data exists (Phase 6).
   `ProfileID` is included as the PEPPOL billing process identifier even though the profile is
   currently EN 16931.
2. **Generation via `Builder::XmlMarkup` (the `builder` gem), not an `.xml.erb` template.** Rails
   only auto-escapes `.html.erb`; `.xml.erb` does **not**, so an unescaped `&`/`<` in a client name
   would produce malformed XML. `Builder` escapes text and attributes automatically. (This
   supersedes the `_milestones.md` wording "`ubl.xml.erb` template".)
3. **Amounts computed in Ruby from line items, not the SQL-`SUM` path.** The XML must reconcile to
   the cent, so the builder sums `LineItem#subtotal` / `#vat_amount` (integer/Ruby) and formats with
   an integer-cents helper — never float division. See `recipes/money-calculations.md`; the full
   `MoneyAmount` value object is still deferred.
4. **Tax category mapping.** Internal codes `S12`/`S5` are *not* UNCL5305 codes — map them to `S`
   and carry the rate in `Percent` (`S→S`, `S12→S`, `S5→S`, `Z→Z`, `E→E`, `AE→AE`, `G→G`).
5. **Amounts `currencyID="EUR"`; `InvoiceTypeCode` = 380 (commercial invoice).**

## Field mapping

| UBL element | Source |
|---|---|
| `cbc:ID` / `IssueDate` / `DueDate` | `invoice_number` / `issued_on` / `due_on` (ISO) |
| `cbc:InvoiceTypeCode` / `DocumentCurrencyCode` | `380` / `EUR` |
| `cbc:Note` | `invoice.notes` (omitted when blank) |
| Supplier / Customer Party | account / client: PartyName, PostalAddress, PartyTaxScheme (`VAT`, omitted when no VAT number), PartyLegalEntity |
| `cac:PaymentMeans` | bank_account (IBAN), bank_swift (BIC), bank_name, due date (omitted when no IBAN) |
| `cac:PaymentTerms` | `account.payment_terms` (omitted when blank) |
| `cac:TaxTotal` → `TaxSubtotal` | one per `[mapped category, vat_rate]` group |
| `cac:LegalMonetaryTotal` | LineExtension/TaxExclusive = subtotal, TaxInclusive/Payable = total |
| `cac:InvoiceLine` | position, quantity + `unitCode`, LineExtensionAmount, Item/Name, ClassifiedTaxCategory, Price/PriceAmount |

## Known gaps / preconditions

- **Seller `country_code`: hard-coded `LV`.** `accounts` has no `country_code` column. Add one if
  non-Latvian sellers are ever supported.
- **Buyer country** falls back to `LV` when `client.country_code` is blank.
- **Category/rate consistency is assumed.** The app stores `tax_category_code` and `vat_rate`
  independently, so a line can be `S` with rate `0`; the builder maps faithfully and does not
  reconcile the two. Tightening this belongs with the `MoneyAmount`/line-item work.
- **Manual validation only.** CI checks well-formedness (Nokogiri) and targeted node values; full
  XSD/Schematron validation (Java + Saxon, or the free e-invoice.be validator) is a manual dev
  step. Not automated in `bin/ci`.

## Out of scope

Credit notes (`InvoiceTypeCode` 381), PDF/A-3 hybrid, PEPPOL transmission (AS4), e-adrese,
Endpoints/EAS schemeIDs, the invoice download-page UI (session 8), and mark-as-sent (session 9).
