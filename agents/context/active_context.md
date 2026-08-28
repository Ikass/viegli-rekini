# Active Context — Viegli-Rēķini

## Current work
Invoice Show View Redesign (vault: Phase 1.5). Spec: `agents/specs/invoice-show-view-spec.md`.

Goal: a single status-aware invoice page that visually matches the print/PDF output. Fixes the two-Edit-buttons ambiguity structurally and locks issued invoices against in-place edits (VID invoice-number integrity).

## State
Redesign Phases 0–6 done: print fix + shared `_document` partial, `Invoice#overdue?`/`display_status`, transition timestamps, status-aware show, locked non-draft edits, draft inline-edit, send-with-save, line-item editor table. Full history in `agents/logs/2026-08-27.md`; feature inventory in `progress.md`.

## Next
- Deferred toolbar stubs: PDF download, resend, reminder, payment link, duplicate, partial-payment UI.
- Long-term: combobox for product/service selection (Option 3) — spec in `agents/specs/line-item-selection-options.md`.

## Decisions locked
- Void = any non-void → void (number reserved); Delete = drafts only.
- `overdue` is derived (sent && due < today), not a DB status.
- Line-item selection: "Add from product" helper (Option 1) for now; combobox (Option 3) is the future target.
- VAT rate is a Product attribute; line items display it read-only today — future direction is category-select-overridable (combobox spec).
