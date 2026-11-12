# Plan: Latvian and English (LV/EN) for viegli-rēķini

Status: draft, 2026-11-12. Owner: Reinis. Executor: OpenCode.

Read AGENTS.md and ARCHITECTURE.md first and follow their conventions (service objects, CUBE CSS, tests, commit style). If something in this plan conflicts with them, stop and ask Reinis.

## Goal

The whole product works in Latvian and English:

- the logged-in app (interface language),
- the public pages: landing page, login/sign-up, legal pages (public language),
- the invoices themselves: PDF, print view and e-invoice text (document language).

Latvian is the default. English must be there from the start because the live site is also shown as a portfolio piece to employers outside Latvia.

## Decisions already made (do not reopen)

1. Default locale is `:lv`. English is `:en`. Design for more locales later: no code that assumes exactly two.
2. Public pages: Latvian at `/`, English at `/en/...`. No `/lv` prefix. Each page has its own URL per language.
3. Logged-in app pages have no locale prefix. The app language is stored on the user (`users.locale`).
4. Document language is separate from interface language. A Latvian user can issue an English invoice. LV and EN invoices must work from the first release.
5. UI text and document text live in separate translation namespaces (see Conventions).
6. The invoice flow stays three steps. Document language is a small selector on the Send step, not an extra step.

## Open questions (answer in the audit, ask Reinis if unclear)

- Are UI strings already in locale files, or hardcoded in views, helpers, controllers, models and JS?
- How are PDF and print view rendered today (library, template location)?
- Are there mailers, or any text sent to the customer besides the PDF/XML?
- Are the public pages served by the Rails app (assumed) or by something else?

## Phase 0: Audit (no code changes)

Write `agents/logs/i18n-audit.md` covering:

- Hardcoded user-visible strings, counted per area (layout/nav, auth, dashboard, customers, items, invoices, settings, flash messages, validation messages, enum/status labels, mailers, JS).
- Every place that formats a date, number or money amount.
- Where the PDF, print view and XML are built, and any text inside the XML builder that depends on language.
- The answers to the open questions above.

Done when the file exists and Reinis has read it.

## Phase 1: Foundation (no behaviour change)

- Add `rails-i18n` (Latvian plural rules and date/number formats) and `i18n-tasks`. Ask before adding anything else.
- `config.i18n.default_locale = :lv`, `available_locales = [:lv, :en]`.
- Raise on missing translations in development and test. In production, `:lv` falls back to `:en` as a safety net only.
- Set `<html lang>` from the current locale in the layout.
- Add the `i18n-tasks` health check (missing and unused keys, normalised files) to whatever command the repo uses for checks/CI.

Done when: tests pass, a deliberately missing key raises in test, the health check runs.

## Phase 2: Extract strings, English first

Move all user-visible text into `config/locales/en/*.yml`, one slice per commit: layout/nav, auth, dashboard, customers, items, invoices, settings, flash messages, validation messages.

Rules:

- Use lazy lookup in views (`t(".title")`).
- Model names, attributes and errors go under `activerecord`.
- Enum and status labels get translated names, not raw values.
- Do not change English wording unless asked. This phase moves text, it does not edit it.
- Shared words (Save, Cancel, Delete) go under `shared.actions`.

Done when `i18n-tasks missing` and `unused` are clean for English and the UI looks unchanged.

## Phase 3: Latvian translations

- Create `agents/context/lv-glossary.md` first and have Reinis review it. Proposed starting terms: rēķins (invoice), e-rēķins, kredītrēķins (credit note), avansa rēķins, pavadzīme (delivery note), piedāvājums (quote), PVN (VAT), reģistrācijas numurs, PVN reģistrācijas numurs, apmaksas termiņš (due date), pircējs and pārdevējs (buyer and seller).
- Write `config/locales/lv/*.yml` using the glossary. Use plain, self-explanatory Latvian, not literal translations.
- Plurals: use `zero`, `one`, `other` for counts. Test 0, 1, 2, 11, 21 and 101, where 1, 21 and 101 take the `one` form.
- Money in Latvian displays like `1 478,00 €` (decimal comma, symbol after). Check what `rails-i18n` outputs and use a non-breaking space in documents so amounts never wrap.

Done when the health check is clean for both locales and Reinis has reviewed the Latvian text.

## Phase 4: Locale handling and the switcher

Public pages:

- Routes: `scope "(:locale)", locale: /en/` for public pages only. Latvian has no prefix.
- URL helpers include the locale only when it is not the default.
- No automatic redirect based on browser language. If the browser prefers English and the visitor is on a Latvian URL, show a dismissible "View in English" banner instead. Redirects confuse crawlers and break shared links.
- Each public page outputs `rel="alternate" hreflang` for `lv` and `en`, `x-default` pointing to the Latvian URL, and a canonical URL per language.
- The language switcher links to the same page in the other language.

App pages:

- Locale order: `current_user.locale`, then a cookie, then default.
- Add `users.locale` (string, default `"lv"`, validated against available locales).
- The switcher saves the choice to the user.
- Add the Cloudflare Web Analytics snippet to public pages in both languages.

Done when request specs cover `/` and `/en`, `<html lang>`, the alternates, the banner and the saved user preference.

## Phase 5: Invoice language

Data:

- Add `companies.default_document_locale` (default `"lv"`), `customers.document_locale` (nullable), and `invoices.document_locale` (not null).
- Validate each against the available locales. Add a check constraint if the SQLite setup allows it.
- Default chain when a draft is created: customer, then company, then `:lv`.
- The value is stored on the invoice and does not change after the invoice is issued. A reprint must look the same as the original.

Rendering:

- Put the document labels in a separate namespace and files: `config/locales/documents.lv.yml` and `documents.en.yml`. Examples: Invoice, Invoice number, Date, Due date, Seller, Buyer, VAT number, Subtotal, VAT, Total, Payment details.
- Render the PDF and print view inside `I18n.with_locale(invoice.document_locale)`. Dates and money follow the document locale, not the user's interface language.
- Free-text parts that the user typed (item names, notes) are never translated.
- The XML builder must not call `I18n` for structural values. Add a test: the same invoice produces identical XML structure under `:lv` and `:en`, apart from free-text fields.
- Any email that carries an invoice uses the document locale.

UI:

- A selector on the Send step, "Invoice language", defaulting from the chain above. Do not add it to the first two steps.
- A setting on the customer form and a company default in settings.

Done when an LV and an EN invoice can be created, previewed, downloaded as PDF and exported as XML, and changing the interface language changes none of the stored invoices.

Legal wording note: the Latvian labels on the invoice must use correct accounting terminology. Reinis should have an accountant review the Latvian invoice template and confirm that English invoices are acceptable for the intended users.

## Phase 6: Public pages in both languages

- Move the landing page copy into a `landing` namespace in both locales.
- The Latvian copy is written separately (Reinis and Claude are doing it). Do not machine-translate it. Do not publish `/` with English text in it. Hold this phase until the Latvian copy is supplied.

Done when `/` shows Latvian, `/en` shows English, and both pass the health check.

## Phase 7: QA and documentation

- Check every screen at 375 px wide in both languages. Latvian text is longer, so look for overflow and wrapping in buttons, badges, table headers and the nav.
- Print styles for both document languages.
- Sitemap lists both language URLs for public pages.
- Update AGENTS.md and ARCHITECTURE.md with a short i18n section: lazy lookup, no hardcoded strings, UI vs document namespaces, locale resolution, how invoice language works.
- Add `docs/recipes/add-a-translation.md`: the steps to add a key, and how to add a new locale later.

## Conventions

- No hardcoded user-visible text in new code, ever.
- UI keys live under `config/locales/<locale>/*.yml`. Document keys live in `documents.<locale>.yml`.
- Key names follow the view or controller path (`invoices.show.title`) except shared ones.
- One commit per slice. Run the full test suite and the i18n health check before each commit.

## Out of scope for now

- A single invoice showing two languages side by side.
- Locales other than Latvian and English.
- Automatic machine translation of user-entered content.
