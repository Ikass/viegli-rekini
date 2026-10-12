# Active Context — Viegli-Rēķini

## Current work
CV-critical fixes (VAT rounding + invoice numbering), mobile/UI polish, system-test hardening, and
the README rewrite are shipped and **live** — re-deployed to `viegli-rekini.lv` 2026-10-11. CI fully
green. Cloudflare Web Analytics shipped on the public login page 2026-10-12. Next: Litestream → R2
backups, then make the repo public.

## State
- Live: HTTPS via Kamal proxy, `/up` healthy, unauth → login. Demo tenant seeded. Re-deployed
  2026-10-11 with the VAT/numbering/UI fixes.
- Repo: GitHub `Ikass/viegli-rekini`; local `/home/reinis/Projects/viegli-rekini`.
- Secrets: GHCR classic PAT at `~/.config/viegli-rekini/ghcr-token`; master key + PAT in
  Bitwarden (both recreated on this machine 2026-10-11). `.kamal/secrets` reads via `$(cat …)`.
- Deploy runbook: `agents/docs/notes/kamal-ovh-deploy.md`. Recurring command: `bin/kamal deploy`.
- Tests: 162 unit + 4 system green; Brakeman 0; bundler-audit + importmap audit clean; CI green on main.
- Analytics: Cloudflare Web Analytics beacon on `/session/new` only (token in credentials
  `cloudflare.web_analytics_token`); strategy in `agents/docs/ANALYTICS-PLAN.md`.

## Next
- `MoneyAmount` VO (optional cleanup; per-category VAT + Ruby sum already shipped).
- Backups (Litestream → R2) still pending.
- Uptime check on `/up` (UptimeRobot/Better Stack); then Ahoy + Blazer for in-app events.
- Make the repo public (README + CI green).

## Decisions locked
- Domain: **`viegli-rekini.lv`**. Image/registry: `ghcr.io/ikass/viegli-rekini` (classic PAT).
- Analytics/monitoring: cookie-less, first-party where possible, **no invoice data in third-party
  tools**. Cloudflare Web Analytics (manual snippet; DNS stays at nic.lv) on public pages only.
- Demo: one-click "Try the demo" (find-only, never create), public signup off, no nightly reset.
- PDF deferred (print view only, button hidden); email off (forgot-password hidden).
- Numbering: number assigned **at send**, not draft (drafts unnumbered → gapless); counter table
  (`invoice_sequences` with `scope`, atomic `INSERT … ON CONFLICT … RETURNING`), not a lock.
- Money/VAT: **per category, rounded once** (EN 16931 BR-CO-17) — done; `LineItem#subtotal` rounds
  half-up; `Invoice#vat_breakdown` is the single source for UBL + print.
- Solid Queue/Cache still deferred; prod `:async` + `:memory_store`.
