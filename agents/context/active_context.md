# Active Context — Viegli-Rēķini

## Current work
Deploy phase — portfolio demo. Phase 1 audit complete; `agents/docs/DEPLOY-PLAN.md` written and
locked. Next action: deploy blockers (A1–A5) + repo rename (B1), then first deploy to OVHCloud (VPS ordered, under review).

## State
- Audit (2026-10-09): 149 unit + 4 system tests green, Brakeman 0 warnings, CI present.
  Working end-to-end: signup/login, clients/products CRUD, invoice create, numbering, print, UBL.
- Deploy blockers found: `SOLID_QUEUE_IN_PUMA` (Puma boot crash), no Chromium in Docker (PDF),
  unconfigured deploy.yml/prod SSL/hosts, Render leftover (`bin/render-build.sh`).
- Two fixes planned (branches after first deploy): numbering counter table, money/VAT rounding.

## Next
- A1 drop `SOLID_QUEUE_IN_PUMA` + guard `plugin :solid_queue`; A2 configure deploy.yml; A3 prod
  hosts/SSL; A4 hide PDF + forgot-password; A5 trim Dockerfile. B1 rename repo → `viegli-rekini`.
- Fix 1 (`fix/invoice-numbering`): counter table, numbers assigned at send, gapless.
- Fix 2 (`fix/money-rounding`): `MoneyAmount` VO, VAT per rate/category (BR-CO-17).
- README rewrite (portfolio-facing) before repo goes public. Secrets scan (report-only).

## Decisions locked
- Domain: **`viegli-rekini.lv`** (owned); `vieglirekini.lv` is a later redirect only.
- Image/registry: `ghcr.io/ikass/viegli-rekini` (classic PAT `write:packages`, out of repo).
- Demo: one-click "Try the demo" (find-only, never create), public signup off, no nightly reset.
- PDF deferred (print view enough) → hide button; email off → hide forgot-password.
- Numbering: number assigned **at send**, not draft (drafts unnumbered → gapless, LV-compliant);
  described as a robustness refactor, not "fixing a race" (SQLite has no row locks — see
  `agents/docs/notes/audit-findings.md`).
- Money/VAT: **per rate/category, rounded once** (EN 16931 BR-CO-17), not sum-of-per-line; delete
  SQL `SUM`. Validate via XSD + BR-CO-10/14/17 arithmetic assertions (full Schematron deferred).
- Queue/cache: Solid Queue/Cache still deferred; prod `:async` + `:memory_store`.
- Litestream → R2 backups still planned; interim backup via `sqlite3 .backup`/`VACUUM INTO`.
