# Latvian glossary — ViegliRēķini (draft for review)

Draft 2026-11-16. Owner: Reinis. This is the vocabulary I'll use to write
`config/locales/lv.yml` (i18n-plan Phase 3). Terms are grounded in the landing
copy already shipped (`landing.lv.yml`) and the proposed list from the plan.

**Please review — especially the "Open choices" section at the end.**

## Rules already locked (from the plan + landing)

- **Informal "tu"** throughout (matches the founder voice and the landing).
- **Money**: `1 478,00 €` — decimal comma, non-breaking space before the symbol,
  symbol after the amount.
- **Plurals**: `zero` / `one` / `other` (1, 21, 101 → `one`).
- **Term consistency**: one Latvian word per concept, used everywhere.

## Core domain terms

| EN | LV | Note |
|---|---|---|
| invoice | rēķins | |
| e-invoice | e-rēķins | |
| credit note | kredītrēķins | future |
| advance invoice | avansa rēķins | future |
| quote | piedāvājums | future |
| VAT | PVN | |
| VAT number | PVN numurs | |
| registration number | reģistrācijas numurs | |
| due date / due on | apmaksas termiņš | |
| issued on | izrakstīšanas datums | |
| buyer | pircējs | |
| seller | pārdevējs | |
| client | klients | |
| product | prece (pl. preces) | |
| line item | pozīcija | "rēķina pozīcija" where full clarity helps |
| goods and services | preces un pakalpojumi | the landing's phrase for invoice items |
| subtotal | summa bez PVN | matches the landing |
| total | kopā | |
| invoice number | rēķina numurs | |
| buyer reference | pircēja atsauce | |
| notes | piezīmes | |
| description | apraksts | |

## Invoice statuses

| EN | LV |
|---|---|
| draft | melnraksts |
| sent | nosūtīts |
| paid | apmaksāts |
| void | anulēts |
| overdue | nokavēts |

## Client enums

| EN | LV |
|---|---|
| delivery channel — email | e-pasts |
| delivery channel — e_adrese | e-adrese |
| VAT regime — standard | standarta |
| VAT regime — reverse charge | apgrieztā maksāšana |
| VAT regime — export | eksports |
| budget institution | budžeta iestāde |

## Unit codes (UN/ECE)

| Code | LV |
|---|---|
| C62 Piece | gab. |
| HUR Hour | stunda |
| DAY Day | diena |
| WEE Week | nedēļa |
| MON Month | mēnesis |
| QAN Quarter | ceturksnis |
| ANN Year | gads |
| KGM Kilogram | kilograms |
| LTR Litre | litrs |
| MTR Metre | metrs |
| PK Pack | iepakojums |
| MTK Square metre | kvadrātmetrs |

## VAT categories (tax category codes)

| EN | LV |
|---|---|
| Standard rate (21%) | standartlikme |
| Reduced rate (12% / 5%) | samazinātā likme |
| Zero rated | nulles likme |
| Exempt from tax | atbrīvots no nodokļa |
| Reverse charge | apgrieztā maksāšana |
| Out of scope | ārpus tvēruma |

## Common actions / buttons

| EN | LV |
|---|---|
| Save | Saglabāt |
| Cancel | Atcelt |
| Delete | Dzēst |
| Edit | Rediģēt |
| Back | Atpakaļ |
| New | Jauns |
| Yes / No | Jā / Nē |
| Send | Nosūtīt |

## Field labels

| EN | LV |
|---|---|
| company name | uzņēmuma nosaukums |
| email | e-pasts |
| address | adrese |
| city | pilsēta |
| postal code | pasta indekss |
| country | valsts |
| country code | valsts kods |
| IBAN | IBAN |
| bank name | bankas nosaukums |
| SWIFT/BIC | SWIFT/BIC |
| payment terms | apmaksas noteikumi |
| invoice prefix | rēķina prefikss |
| number padding | numura garums |
| quantity | daudzums |
| unit | mērvienība |
| unit price | vienības cena |
| VAT rate | PVN likme |
| VAT category | PVN kategorija |

## Dashboard / auth

| EN | LV |
|---|---|
| dashboard | panelis |
| outstanding | neapmaksāts |
| overdue | nokavēts |
| paid (this month) | apmaksāts (šajā mēnesī) |
| recent activity | pēdējā aktivitāte |
| view all | skatīt visus |
| sign in | pieslēgties |
| password | parole |
| sign out | izrakstīties |
| try the demo | izmēģini demo |
| forgot your password? | aizmirsi paroli? |

## Open choices — please confirm or correct

1. **"Dashboard"** → *panelis* (standard Latvian SaaS term). Alternative: *sākums*
   (ties in with "sākuma ekrāns" on the landing). I'd go with *panelis*.
2. **"Void"** → *anulēts* (annulled). Alternative: *atcelts* (cancelled).
   *Anulēts* is the stronger, more accounting-appropriate word.
3. **"Line item"** → *pozīcija*. Alternative: *rinda* (row) or *prece un
   pakalpojums*. *Pozīcija* is the standard invoice term.
4. **"Reverse charge"** → *apgrieztā maksāšana* (the PVN likums term). Kept as the
   full phrase rather than a short label, since it appears in a select dropdown.
5. **"Bill to"** (invoice document) → *pircējs*. The plan suggested pircējs/
   pārdevējs for buyer/seller — I'll use those on the invoice document.
6. **"Sign out"** → *izrakstīties* (the reflexive "to sign oneself out"); "sign in"
   → *pieslēgties*. Mirrors the landing's "Pieslēgties" for login.
