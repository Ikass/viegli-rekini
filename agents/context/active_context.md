# Active Context — Viegli-Rēķini

## Current work
Both CV-critical fixes (VAT rounding + invoice numbering) and the flaky system-test hardening are
done, committed, and pushed — GitHub CI is fully green (test, system-test, lint, scan_ruby, scan_js).
Next: README rewrite (portfolio-facing) before making the repo public.

## State
- Live: HTTPS via Kamal proxy, `/up` healthy, unauth → login. Demo tenant seeded.
- Repo: GitHub `Ikass/viegli-rekini`; local `/home/reinis/Projects/viegli-rekini`.
- Secrets: GHCR classic PAT at `~/.config/viegli-rekini/ghcr-token`; master key + PAT in
  Bitwarden (both recreated on this machine 2026-10-11). `.kamal/secrets` reads via `$(cat …)`.
- Deploy runbook: `agents/docs/notes/kamal-ovh-deploy.md`. Recurring command: `bin/kamal deploy`.
- Tests: 162 unit + 4 system green; Brakeman 0; bundler-audit + importmap audit clean; CI green on main.

## Next
- `MoneyAmount` VO (optional cleanup; per-category VAT + Ruby sum already shipped).
- README rewrite (portfolio-facing) before repo goes public.
- Backups (Litestream → R2) still pending.

## Decisions locked
- Domain: **`viegli-rekini.lv`**. Image/registry: `ghcr.io/ikass/viegli-rekini` (classic PAT).
- Demo: one-click "Try the demo" (find-only, never create), public signup off, no nightly reset.
- PDF deferred (print view only, button hidden); email off (forgot-password hidden).
- Numbering: number assigned **at send**, not draft (drafts unnumbered → gapless); counter table
  (`invoice_sequences` with `scope`, atomic `INSERT … ON CONFLICT … RETURNING`), not a lock.
- Money/VAT: **per category, rounded once** (EN 16931 BR-CO-17) — done; `LineItem#subtotal` rounds
  half-up; `Invoice#vat_breakdown` is the single source for UBL + print.
- Solid Queue/Cache still deferred; prod `:async` + `:memory_store`.
