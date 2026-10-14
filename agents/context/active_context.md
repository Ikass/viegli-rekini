# Active Context — Viegli-Rēķini

## Current work
CV-critical fixes, mobile/UI polish, system-test hardening, and the README rewrite are live
(re-deployed 2026-10-11). Cloudflare Web Analytics shipped on the login page (2026-10-12). Latest:
the UBL XML export now targets **Peppol BIS Billing 3.0** — seller/buyer `EndpointID` (Latvia VAT
`9939` / registration `0218`), `BuyerReference` (`N/A` fallback), and a seller-VAT guard. Built +
tested 2026-10-12; awaiting a manual Peppol web validation. Sentry error tracking built 2026-10-14
(`sentry-ruby`/`sentry-rails`, EU DSN in credentials, `send_default_pii=false`, `ScrubInvoiceData`
PII scrubber) — code done, deploy pending. Next: Litestream → R2 backups.

## State
- Live: HTTPS via Kamal proxy, `/up` healthy, unauth → login. Demo tenant seeded. Re-deployed
  2026-10-11 with the VAT/numbering/UI fixes.
- Repo: GitHub `Ikass/viegli-rekini` (**public**); local `/home/reinis/Projects/viegli-rekini`.
- Secrets: GHCR classic PAT at `~/.config/viegli-rekini/ghcr-token`; master key + PAT in
  Bitwarden (both recreated on this machine 2026-10-11). `.kamal/secrets` reads via `$(cat …)`.
- Deploy runbook: `agents/docs/notes/kamal-ovh-deploy.md`. Recurring command: `bin/kamal deploy`.
- Tests: 174 unit + 4 system green; Brakeman 0; bundler-audit + importmap audit clean; CI green on main.
- Analytics: Cloudflare Web Analytics beacon on `/session/new` only (token in credentials
  `cloudflare.web_analytics_token`); strategy in `agents/docs/ANALYTICS-PLAN.md`. Sentry error
  tracking wired (EU DSN, `send_default_pii=false`, `ScrubInvoiceData` scrubber); not yet deployed.
- XML export: Peppol BIS Billing 3.0 (EN 16931 + BIS 3.0 `CustomizationID`); EndpointID schemes
  `9939`/`0218`; manual validation documented in `agents/docs/specs/ubl-invoice-generation.md`.

## Next
- Deploy Sentry wiring and verify one test event lands (EU region).
- `MoneyAmount` VO (optional cleanup; per-category VAT + Ruby sum already shipped).
- Backups (Litestream → R2) still pending.
- Uptime check on `/up` (UptimeRobot/Better Stack); then Ahoy + Blazer for in-app events.

## Decisions locked
- Domain: **`viegli-rekini.lv`**. Image/registry: `ghcr.io/ikass/viegli-rekini` (classic PAT).
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
