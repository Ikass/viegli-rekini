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
- `recipes/invoice-number-sequences.md` — dedicated counter table, multiple sequences per account (location + ecommerce). Decided direction, not built.
- `recipes/money-calculations.md` — consolidate on Ruby BigDecimal + `MoneyAmount` value object; drop SQL SUM. Decided direction, not built.

## Specs (proposals / recorded decisions)

- `specs/invoice-show-view-spec.md` — status-aware invoice show view design.
- `specs/invoice-print-styling.md` — print/PDF styling review + prioritized implementation plan (fonts, money precision, localization, `.addresses` grid).
- `specs/line-item-selection-options.md` — line-item select-or-create combobox direction.
- `specs/ubl-invoice-generation.md` — UBL 2.1 / EN 16931 XML builder: profile decision, BT mapping, category mapping, money handling, known gaps.
