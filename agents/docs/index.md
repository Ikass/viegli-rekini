# Agent Docs Index

The map of every doc under `agents/`. **Read this first** on any task, then open the file it
points to. Keep it current — add or update a line whenever you create or move a doc.

---

## Contracts (canon — always follow)

| File | Covers |
|---|---|
| [tenancy.md](contracts/tenancy.md) | The one scoping pattern every tenant-owned resource follows; new-resource checklist |
| [service-objects.md](contracts/service-objects.md) | One service per state transition; `Result` struct; audit inside the transaction |

## Recipes (non-canon — opt-in, not built yet)

| File | Reach for when |
|---|---|
| [audit-events.md](recipes/audit-events.md) | You need "who did this, when" for a VID inquiry or client dispute |
| [entitlements-lite.md](recipes/entitlements-lite.md) | A pricing decision lands and product code must ask "can this account do X" |

## Specs (proposals — confirm open questions before implementing)

| File | Scope |
|---|---|
| [invoice-show-view-spec.md](../specs/invoice-show-view-spec.md) | Status-aware single show view; open questions on void/delete, viewed-tracking, mark-as-paid |
| [line-item-selection-options.md](../specs/line-item-selection-options.md) | Product-picker → combobox (select-or-create) evolution |

## Session state (not docs — read for context, never treat as locked)

- `../context/active_context.md` — what's in progress right now
- `../context/progress.md` — rolling summary of what's built (overwrites on purpose)
- `../logs/` — append-only per-session build log
- `../../LEARNING.md` — curated how/why-built guide; durable decisions + lessons promoted from `logs/`
