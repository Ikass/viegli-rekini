# Active Context — Viegli-Rēķini

## Current work
Invoice Show View Redesign (vault: Phase 1.5). Spec: `agents/invoice-show-view-spec.md`.

Goal: a single status-aware invoice page that visually matches the print/PDF output. Fixes the two-Edit-buttons ambiguity structurally and locks issued invoices against in-place edits (VID invoice-number integrity).

## Done this session (2026-08-27)
- Phase 0: removed broken `<# if %>` PEPPOL block from print template + regression tests.
- Phase 1: extracted `app/views/invoices/_document.html.erb` shared partial; moved print CSS into `blocks/invoice-doc.css` (scoped `.invoice-doc`).
- Phase 2: `Invoice#overdue?` + `display_status` + `overdue` badge variant.
- Phase 4: `sent_at`/`paid_at`/`voided_at` timestamps set in transition services.
- Phase 3: status-aware `show` — sticky toolbar, status badge + number, shared document, activity strip.
- Phase 5: locked `edit`/`update`/`destroy` (invoice + line items) for non-drafts.
- Phase 6 (stage 2): draft show page renders the editable form inline; `/edit` now redirects to `show`.

## Next
- Polish (deferred from stage 2): style the draft form to match the document; line-item rows as editable table cells (currently card-based form).

## Decisions locked
- Void = any non-void → void (number reserved); Delete = drafts only.
- `overdue` is derived (sent && due < today), not a DB status.
- Deferred: PDF download, resend, reminder, payment link, duplicate, partial-payment UI.
