# Spec: UBL 2.1 e-invoice generation (Peppol BIS Billing 3.0)

**Status:** built 2026-10-07 (EN 16931); **updated 2026-10-12** to target Peppol BIS Billing 3.0.
**Scope:** `UblInvoiceBuilder`, the `get :ubl` member route, `InvoicesController#ubl`, and the
`invoices.buyer_reference` field.
**Docs source:** docs.peppol.eu, Peppol BIS Billing 3.0 — **May 2026 release** (checked 2026-10-12).
Cite this version — the BIS spec and its validation rules change between releases.

## What this does

Renders an `Invoice` as a UBL 2.1 XML document valid under **Peppol BIS Billing 3.0** (the EN 16931
semantic model + the BIS 3.0 `CustomizationID`), the practical format for Latvian B2G (mandatory
since 2025) and the coming B2B mandate (mandatory from 2028, voluntary since March 2026).

## Shape

`UblInvoiceBuilder` is a **pure renderer**, not a state transition, so it follows the `InvoicePdf`
shape (`new(invoice)` + public readers + `#filename`) rather than the `Result`-struct shape in
`contracts/service-objects.md`. Callers get a string and a filename; nothing is persisted.

## Decisions

1. **Target = Peppol BIS Billing 3.0.** `CustomizationID =
   urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0`; `ProfileID` stays
   `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0`. (Supersedes the earlier EN-16931-only target.)
2. **Electronic addresses (`cbc:EndpointID`).** Peppol requires seller and buyer endpoints
   (PEPPOL-EN16931-R010) with a scheme from the CEF EAS code list (BR-CL-25,
   PEPPOL-EN16931-CL008 — fatal). Emitted as the **first child of `cac:Party`**:
   - Seller → scheme `9939` ("Latvia VAT number") + the seller VAT number.
   - Buyer → `9939` + VAT number when present (country prefix kept); else `0218` ("Unified
     registration number (Latvia)") + registration number.
   - **Email (`EM`) is not used**: the BIS 3.0 EAS list has no email code, so a private-person buyer
     with neither identifier blocks the export (see the guard below).
3. **Legal registration identifier.** `PartyLegalEntity/cbc:CompanyID` carries `schemeID="0218"`
   (ISO 6523 ICD list, "Unified registration number (Latvia)"). The VAT number's scheme (`VAT`)
   lives in `cac:TaxScheme/cbc:ID`, not as a `CompanyID` attribute.
4. **`cbc:BuyerReference`.** Peppol requires a buyer reference or order reference
   (PEPPOL-EN16931-R003). Emitted after `DocumentCurrencyCode`; `N/A` when the invoice has none.
5. **Generation via `Builder::XmlMarkup`** (not `.xml.erb`) — auto-escapes text/attributes.
6. **Amounts computed in Ruby from line items** (integer cents), never float/SQL — see
   `recipes/money-calculations.md`.
7. **Tax category mapping** (`S12`/`S5`→`S` carrying the rate in `Percent`; `Z`/`E`/`AE`/`G`
   passthrough). Single source: `InvoiceCodes#tax_category_for`.
8. **`currencyID="EUR"`; `InvoiceTypeCode` 380 (commercial invoice); `PaymentMeansCode` 30.**

## Field mapping

| UBL element | Source |
|---|---|
| `cbc:CustomizationID` / `ProfileID` | BIS 3.0 constants above |
| `cbc:ID` / `IssueDate` / `DueDate` | `invoice_number` / `issued_on` / `due_on` (ISO) |
| `cbc:InvoiceTypeCode` / `DocumentCurrencyCode` | `380` / `EUR` |
| `cbc:BuyerReference` | `invoice.buyer_reference` (`N/A` when blank) |
| `cbc:Note` | `invoice.notes` (omitted when blank) |
| Supplier `cbc:EndpointID` | `account.vat_number`, scheme `9939` (first Party child) |
| Buyer `cbc:EndpointID` | `client.vat_number` (scheme `9939`) else `client.registration_number` (scheme `0218`) |
| `PartyLegalEntity/cbc:CompanyID` | `registration_number`, scheme `0218` |
| Supplier/Customer Party | PartyName, PostalAddress, PartyTaxScheme (`VAT`, omitted when no VAT number) |
| `cac:PaymentMeans` | `bank_account` (IBAN), account holder name (`party_name(account)`), `bank_swift` (BIC). **No `PaymentDueDate`** (UBL-CR-412). Omitted when no IBAN. |
| `cac:PaymentTerms` | `account.payment_terms` (omitted when blank) |
| `cac:TaxTotal` → `TaxSubtotal` | one per `[mapped category, vat_rate]` group |
| `cac:LegalMonetaryTotal` | LineExtension/TaxExclusive = subtotal, TaxInclusive/Payable = total |
| `cac:InvoiceLine` | position, quantity + `unitCode`, LineExtensionAmount, Item/Name, ClassifiedTaxCategory, Price/PriceAmount |

## Seller VAT assumption & guard

The builder **assumes every seller is VAT-registered**: it always emits the seller VAT ID in
`PartyTaxScheme` and uses it for the seller endpoint. `InvoicesController#ubl` **guards** this —
when `account.vat_number` is blank (or the buyer has no VAT/registration number), it redirects with
a flash instead of producing an invalid file. Tests cover both branches.

**Why non-VAT sellers can't be added cheaply:** Peppol BIS 3.0 requires a seller VAT ID for
standard-rated lines (**BR-S-02**) and forbids it for category `O` "not subject to VAT"
(**BR-O-02**), so supporting them means category `O` + different endpoint scheme + no seller VAT ID
— separate work, not yet in scope.

## VAT categories (current vs. Peppol)

The builder supports `S` (incl. reduced rates `S12`/`S5` folded into `S` with their `Percent`),
`Z`, `E`, `AE`, `G`. It does **not** yet emit `cbc:TaxExemptionReasonCode`/`cbc:TaxExemptionReason`
for `E`/`AE`, which Peppol requires for exempt categories. For `E`, **BR-E-10** needs an exemption
reason code **or** text (not both). `O` and `K` are not supported. Not implementing new categories
now — documented for the future.

## Manual validation procedure

1. Generate the XML with the download button for a **test invoice only**. Never upload real
   customer invoices to third-party web validators.
2. Validate with a Peppol-capable web validator. The eConnect validator (econnect.eu) is free and
   detects the BIS Billing V3 profile automatically.
3. Optionally run the EC eInvoicing validator (itb.ec.europa.eu/invoice, type "UBL Invoice XML")
   as an EN 16931 base-rule check — it does **not** cover Peppol BIS rules.
4. Expected result: 0 errors / 0 warnings. Re-check periodically; the BIS spec and rules update
   regularly.

## Future option (not implemented)

A self-hosted Peppol validator — the Docker image `easybill/peppol-bis-billing-validator` runs the
official Peppol BIS 3.0 Schematron rules behind a small HTTP endpoint (POST the XML to
`/validation`). Pros: runs locally/in CI, no data leaves the machine. Caveats: as of 2026-10 its
Docker Hub page showed no update for over a year — check currency or run the official OpenPEPPOL
Schematron artefacts directly, and confirm it includes the EN 16931 base rules. A paid API exists
(Truugo). If automated later, gate behind an env var so the normal test run stays fast/offline.

## Out of scope

Credit notes (`InvoiceTypeCode` 381), PDF/A-3 hybrid, PEPPOL transmission via an access point (AS4),
Latvian e-adrese, VID reporting, non-VAT-registered sellers, and VAT categories `O`/`K`.
