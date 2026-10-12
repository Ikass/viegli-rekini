# opencode task brief — Make the UBL XML export a valid Peppol BIS Billing 3.0 invoice

> **Status:** received 2026-10-12 — active. Supersedes the earlier `opencode-xml-validation.md`
> (that brief was never implemented; we only reached plan stage before the scope changed to
> Peppol BIS 3.0). Where the two disagree, this file wins (notably: `ProfileID` is kept, not removed).

## Context and decisions

The app is a Rails 8 e-invoicing SaaS for Latvian solopreneurs/small businesses. The XML download
button currently produces valid EN 16931 UBL 2.1 (confirmed with the EC eInvoicing validator,
0 errors, 1 warning), but it is **not** valid Peppol BIS Billing 3.0. In Latvia the practical format
for B2G (mandatory since 2025) and the coming B2B mandate (mandatory from 2028, voluntary since
March 2026) is Peppol BIS Billing 3.0.

Decisions made:

1. **Target: Peppol BIS Billing 3.0 for every invoice**, including invoices to private persons
   (they need workarounds, see below).
2. **Validation for now is a manual web check.** Do not build an automated online validation test in
   this task. Document the manual procedure and note the Docker option for the future (Part 5).
3. **Assume all sellers are VAT-registered.** This is a known limitation that must be documented and
   guarded (Part 3), not silently ignored.
4. Out of scope: sending via a Peppol access point, Latvian e-adrese, reporting to VID (State
   Revenue Service), credit notes, non-VAT-registered sellers.

## Verify before implementing (report back, don't assume)

- Which `schemeID` applies to a **Latvian VAT-registered seller's** `cbc:EndpointID` and value.
  Working hypothesis: scheme `9939` with the Latvian VAT number.
- Whether the **email scheme (`EM`)** is a valid EAS code, so a private-person buyer's `EndpointID`
  can be their email address.
- Whether `cac:PartyLegalEntity/cbc:CompanyID` should carry a `schemeID` in Peppol BIS 3.0 when
  emitted (and which one for Latvian registration numbers).
- Which VAT categories the builder currently supports, and what Peppol requires for others (e.g.
  exemption reasons for `E`). Just report; don't implement new categories now.

## Part 1: Carry-over fixes

1. Remove `cbc:PaymentDueDate` from `cac:PaymentMeans` (UBL-CR-412). Due date stays in header
   `cbc:DueDate`.
2. `cac:PayeeFinancialAccount/cbc:Name` must be the account holder name (BT-85), not the bank name.
   Use the seller's legal name via `party_name(@account)`. Keep BIC.

## Part 2: Peppol BIS 3.0 changes in the builder

1. **CustomizationID:** `urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0`
2. **ProfileID:** keep `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0`.
3. **Seller `cbc:EndpointID`** with `schemeID`: required, first child of `cac:Party`.
4. **Buyer `cbc:EndpointID`** with `schemeID`: required, same placement. Business buyer → Latvian
   scheme; private person → email scheme (if verified). Stop and ask if the identifier is missing.
5. **`cbc:BuyerReference`:** required (PEPPOL-EN16931-R003 allows an order reference instead). Add
   optional "buyer reference" field to the invoice (migration, form field with Latvian label,
   strong params). Emit after `cbc:DocumentCurrencyCode`. When blank, emit `N/A`.
6. If `PartyLegalEntity/CompanyID` is emitted, add the `schemeID` per verification.
7. Everything else (type 380, unit codes, PaymentMeansCode 30, totals) stays as is.

## Part 3: Seller VAT assumption (guard + document)

- The builder always emits the seller VAT ID in `PartyTaxScheme` and uses it for the endpoint.
- Add a code comment stating the assumption.
- Guard: if the seller's VAT number is blank, the XML download must not emit an invalid file — show a
  clear user-friendly message. Add a test.
- Document that non-VAT-registered sellers are **not supported** yet.

## Part 4: Tests (offline, every `bin/rails test`)

Update `test/services/ubl_invoice_builder_test.rb`. Assert well-formed XML; `CustomizationID` +
`ProfileID` equal the Peppol values; `PaymentMeans` has no `PaymentDueDate` and header `DueDate`
present; `PayeeFinancialAccount/Name` = seller legal name; seller+buyer `EndpointID` exist with
`schemeID` as first child of `cac:Party`; `BuyerReference` = value or `N/A`; self-consistent totals
computed from the XML; missing seller VAT handled by the guard.

## Part 5: Docs (no implementation)

Update `agents/docs/specs/ubl-invoice-generation.md` and README ("Tests & CI") with: mapping/decisions,
known limitations (VAT-registered sellers), manual validation procedure (eConnect + EC validator),
and a future option (self-hosted `easybill/peppol-bis-billing-validator` Docker image, or official
OpenPEPPOL Schematron artefacts; Truugo paid API). Cite the docs version used.

## Acceptance criteria

- Sample invoice validates in a Peppol-capable web validator with 0 errors / 0 warnings.
- Offline tests pass with `bin/rails test`.
- VAT guard works and is tested.
- Docs updated.
- Final summary: files changed, migrations added, verification answers with sources, open questions.

## Notes

- Test IBANs/VAT/company numbers in fixtures are fake. Don't "fix" them.
- Peppol BIS spec changes between releases — cite the docs version used.
