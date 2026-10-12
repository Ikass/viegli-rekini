# agents/docs — index

The map for the `agents/docs/` tree. Read this first — a doc not listed here is invisible.

## Reading order (before any non-trivial change)

1. `AGENTS.md` (repo root) — line-level rules, quick commands, gotchas.
2. `ARCHITECTURE.md` (repo root) — *why* the app is shaped this way.
3. This index — find the contract / recipe / spec that applies.
4. The relevant doc below, then the closest existing implementation.

## Contracts (canon — always follow)

- `contracts/tenancy.md` — how tenant-owned records are scoped (`Current.user.account…find_by!`), plus the foreign-key rule (`client_id` must be resolved through the account, never trusted verbatim).
- `contracts/service-objects.md` — one-service-per-transition shape returning a `Result` struct.

## Recipes (non-canon — opt-in, reach for when a capability is needed)

- `recipes/audit-events.md` — explicit, service-side audit trail for sensitive operations. Not built yet.
- `recipes/entitlements-lite.md` — Entitlements / Limits split sized for "no billing yet". Not built yet.
- `recipes/invoice-number-sequences.md` — dedicated counter table, multiple sequences per account (location + ecommerce). **Built (2026-10-11).**
- `recipes/money-calculations.md` — consolidate on Ruby BigDecimal + `MoneyAmount` value object; drop SQL SUM. **Built (2026-10-11)**; `MoneyAmount` VO still deferred.

## Specs (proposals / recorded decisions)

- `specs/invoice-show-view-spec.md` — status-aware invoice show view design.
- `specs/invoice-print-styling.md` — print/PDF styling review + prioritized implementation plan (fonts, money precision, localization, `.addresses` grid).
- `specs/line-item-selection-options.md` — line-item select-or-create combobox direction.
- `specs/ubl-invoice-generation.md` — UBL 2.1 / EN 16931 XML builder: profile decision, BT mapping, category mapping, money handling, known gaps.

## Plans

- `DEPLOY-PLAN.md` — portfolio-demo deploy plan: blockers, demo account, Fix 1 (numbering), Fix 2 (money), README, secrets scan.
- `ANALYTICS-PLAN.md` — analytics/monitoring strategy: Cloudflare Web Analytics (built), Ahoy + Blazer, Sentry/GlitchTip, Mission Control, Uptime, Umami fallback, RentForge crossover.

## Notes (deep-dive explainers — read when you need to *understand*, not just follow)

- `notes/audit-findings.md` — the deploy audit's hard-won details: SQLite has no row locks (`with_lock`/`lock!` is a no-op but `BEGIN IMMEDIATE` serializes writes anyway), EN 16931 VAT rounds per *rate category* (BR-CO-14/17), gapless numbering means drafts must not consume numbers, and the deferred Solid stack + the `SOLID_QUEUE_IN_PUMA` boot bug.
- `notes/kamal-ovh-deploy.md` — OVH/Kamal deploy runbook: one-time prerequisites, commands, and the three gotchas that each cost a deploy iteration (empty `env/clear`, health-check host authorization, no backups).
- `notes/cloudflare-web-analytics-setup.md` — Cloudflare Web Analytics beacon on the public login page only: where the snippet lives, why the `auth` layout isn't used, the credentials key, and the CSP/referrer caveats if CSP is ever enabled.
- `notes/opencode-peppol-bis-billing-3.0.md` — active task brief: make the UBL export a valid Peppol BIS Billing 3.0 invoice (CustomizationID/ProfileID, EndpointIDs, BuyerReference, VAT guard). Supersedes the earlier `opencode-xml-validation.md`.
