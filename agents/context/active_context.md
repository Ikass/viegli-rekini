# Active Context — Viegli-Rēķini

## Current work
Deploy phase — **live at https://viegli-rekini.lv** (first deploy 2026-10-09). Deploy blockers
(A1–A5), repo rename (B1), and demo account (C1–C4) all shipped on `main`. Next: the two fix
branches, then README rewrite + secrets scan before making the repo public.

## State
- Live: HTTPS via Kamal proxy, `/up` healthy, unauth → login. Demo tenant seeded (run
  `bin/kamal app exec -i bin/rails db:seed` if resetting).
- Deploy runbook: `agents/docs/notes/kamal-ovh-deploy.md` (OVH `ubuntu` SSH, empty `env/clear`
  hash, `/up` host-authorization exclusion, no backups yet).
- Tests: 150 unit + 4 system green. Brakeman 0 warnings. CI present.

## Next
- Fix 1 (`fix/invoice-numbering`): counter table, numbers assigned at send, gapless.
- Fix 2 (`fix/money-rounding`): `MoneyAmount` VO, VAT per rate/category (BR-CO-17), delete SQL SUM.
- README rewrite (portfolio-facing) before repo goes public. Secrets scan (gitleaks, report-only).
- Backups (Litestream → R2) still pending.

## Decisions locked
- Domain: **`viegli-rekini.lv`**. Image/registry: `ghcr.io/ikass/viegli-rekini` (classic PAT).
- Demo: one-click "Try the demo" (find-only, never create), public signup off, no nightly reset.
- PDF deferred (print view only, button hidden); email off (forgot-password hidden).
- Numbering: number assigned **at send**, not draft (drafts unnumbered → gapless); counter table
  = robustness refactor, not "fixing a race" (SQLite has no row locks — `notes/audit-findings.md`).
- Money/VAT: **per rate/category, rounded once** (EN 16931 BR-CO-17), not sum-of-per-line.
- Solid Queue/Cache still deferred; prod `:async` + `:memory_store`.
