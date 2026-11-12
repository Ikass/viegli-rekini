# Active Context — ViegliRēķini

## Current work
The English landing page shipped (2026-11-12) as the first slice of the i18n plan (Phase 6):
`/` → 302 to `/en` (Latvian copy pending), `/dashboard` is now the app home, brand is
`ViegliRēķini`, and the design system palette + fonts were reconciled to the mockup (coral
`#C8452B`, teal `#0E4F52`, cream `#FBF5E6`; IBM Plex Sans/Serif self-hosted). i18n foundation
landed (`available_locales [:lv, :en]`, `switch_locale`, `landing.{en,lv}.yml`). Plan:
`agents/docs/landing-page-plan.md`. Tests: 191 unit + 4 system green.

Older (still live): CV-critical fixes, mobile/UI polish, system-test hardening, and the README
rewrite (re-deployed 2026-10-11). Cloudflare Web Analytics on the login page (2026-10-12). The
UBL XML export targets **Peppol BIS Billing 3.0** — built + tested 2026-10-12; awaiting a manual
Peppol web validation. Sentry error tracking built + deployed 2026-10-14 (EU DSN,
`send_default_pii=false`, `ScrubInvoiceData` scrubber). Next: Litestream → R2 backups.

## State
- Live: HTTPS via Kamal proxy, `/up` healthy, unauth → login. Demo tenant seeded. Re-deployed
  2026-10-11 with the VAT/numbering/UI fixes.
- Repo: GitHub `Ikass/viegli-rekini` (**public**); local `/home/reinis/Projects/viegli-rekini`.
- Secrets: GHCR classic PAT at `~/.config/viegli-rekini/ghcr-token`; master key + PAT in
  Bitwarden (both recreated on this machine 2026-10-11). `.kamal/secrets` reads via `$(cat …)`.
- Deploy runbook: `agents/docs/notes/kamal-ovh-deploy.md`. Recurring command: `bin/kamal deploy`.
- Tests: 191 unit + 4 system green; Brakeman 0; bundler-audit + importmap audit clean; CI green on main.
- Analytics: Cloudflare Web Analytics beacon on `/session/new` only (token in credentials
  `cloudflare.web_analytics_token`); strategy in `agents/docs/ANALYTICS-PLAN.md`. Sentry error
  tracking live (EU DSN, `send_default_pii=false`, `ScrubInvoiceData` scrubber).
- XML export: Peppol BIS Billing 3.0 (EN 16931 + BIS 3.0 `CustomizationID`); EndpointID schemes
  `9939`/`0218`; manual validation documented in `agents/docs/specs/ubl-invoice-generation.md`.

## Next
- Landing: write the Latvian copy (`landing.lv.yml`), flip `/` from redirect to a real page, add
  `hreflang`/canonical + a language switcher (i18n-plan Phases 4/6).
- i18n-plan Phases 2–5 (extract app strings, add `rails-i18n` + `i18n-tasks`, Latvian app UI,
  invoice document language) — not started.
- Fill the landing placeholders (pricing numbers, FAQ answers, legal pages) when decided.
- `MoneyAmount` VO (optional cleanup). Backups (Litestream → R2) still pending. Uptime check on
  `/up`; then Ahoy + Blazer.

## Decisions locked
- Domain: **`viegli-rekini.lv`**. Image/registry: `ghcr.io/ikass/viegli-rekini` (classic PAT).
- Brand: **`ViegliRēķini`** (no hyphen/space). Landing lives at `/` (LV, default) and `/en`; the
  authenticated app home is `/dashboard`. English ships first; `/` 302s to `/en` until LV copy lands.
- Landing: reconciled into the one design system — coral `#C8452B` / teal `#0E4F52` / cream
  `#FBF5E6`, IBM Plex Sans (body) + Serif (headings) self-hosted (latin + latin-ext).
- Analytics/monitoring: cookie-less, first-party where possible, **no invoice data in third-party
  tools**. Cloudflare Web Analytics (manual snippet; DNS stays at nic.lv) on public pages only.
- XML export: **Peppol BIS Billing 3.0 for every invoice**; seller assumed VAT-registered (guard
  blocks otherwise); buyer endpoint = VAT `9939` else registration `0218`; **no email `EM` scheme**
  (not in the BIS 3.0 EAS list). Manual web validation only for now.
- Demo: one-click "Try the demo" (find-only, never create), public signup off, no nightly reset.
- PDF deferred (print view only, button hidden); email off (forgot-password hidden).
- Numbering: number assigned **at send**, not draft (drafts unnumbered → gapless); counter table
  (`invoice_sequences` with `scope`, atomic `INSERT … ON CONFLICT … RETURNING`), not a lock.
- Money/VAT: **per category, rounded once** (EN 16931 BR-CO-17) — done; `LineItem#subtotal` rounds
  half-up; `Invoice#vat_breakdown` is the single source for UBL + print.
- Solid Queue/Cache still deferred; prod `:async` + `:memory_store`.
