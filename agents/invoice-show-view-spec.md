# Invoice Show View — Redesign Spec

**Project:** viegli-rēķini
**Scope:** `Invoices#show` (and its relationship to `#edit`), plus the print/PDF template
**Stack notes:** Rails 8, Hotwire, CUBE CSS (no Tailwind, no component framework) — existing design system already has tokens, badges, cards, tables, buttons with `data-*` variants, flow utility, Every Layout primitives (stack, cluster, sidebar, grid)

## 1. Core decision: status-aware single view, not separate view/edit screens

The current implementation treats "view" and "edit" as two different screens even while an invoice is still a draft, which produces duplicate/ambiguous "Edit" affordances (one for the whole invoice, one per line item).

**New model: one screen, behavior branches on `invoice.status`.**

- **`draft`** → the show page *is* an inline-editable document. Line items, client block, dates are editable directly in place. No separate `/edit` route needed for drafts (Stripe's dashboard follows this same pattern — opening a draft invoice opens the editable form directly, not a static view page with edit buttons layered on top).
- **`sent` / `paid` / `overdue`** → the show page becomes a true read-only rendering of the document (visually matching the print/PDF output), with a locked line-items table. Correcting a mistake here means **duplicate → new draft** or **issue a credit note**, not editing in place — this protects invoice-number integrity for VID compliance.
- **`void`** → same read-only rendering, with a clear "Voided" watermark/badge treatment so it's unambiguous this invoice no longer counts.

This eliminates the two-Edit-buttons problem structurally rather than cosmetically.

## 2. Layout: single column, not sidebar

Decision (see prior discussion): a permanent right-hand metadata sidebar was considered and rejected. Reasons:
- Issued/due dates and client info are already printed on the document itself — a sidebar duplicates them rather than adding information.
- Doesn't collapse gracefully to mobile, and phone use (tradesmen, solopreneurs checking an invoice on the go) is a realistic case here.
- Single column keeps the "what you see is what gets sent" promise intact — no second visual zone competing with the document.

**Structure, top to bottom, single column, max-width centered (~760–840px on desktop, full width on mobile):**

1. Sticky toolbar
2. Status badge + invoice number
3. The document itself (business header, bill-to, dates, line items, totals, payment details, legal footer) — styled to visually match the print/PDF template
4. Activity strip (timeline) — only genuinely new information not already on the document, so it earns a separate zone below, not beside

## 3. Component breakdown

### 3.1 Sticky toolbar
Sits above the document, sticky on scroll. Content varies by status:

| Status | Primary action | Secondary (inline) | Overflow menu (`⋯ More`) |
|---|---|---|---|
| draft | Send invoice | Download PDF (preview) | Delete draft |
| sent | Resend | Download PDF, Copy payment link | Duplicate, Void, Mark as paid |
| paid | Download PDF | — | Duplicate, Void |
| overdue | Send reminder | Download PDF, Copy payment link | Duplicate, Void, Mark as paid |
| void | Download PDF | — | Duplicate |

Rules:
- Exactly **one** primary button, solid/filled, brand accent color (coral).
- Everything destructive or rare (Void, Delete) lives in the overflow menu, never as a standalone top-level button. Clicking either requires a confirmation dialog stating the consequence in plain language (e.g. "Voiding keeps this invoice number reserved but marks it as cancelled. This can't be undone.").
- "Back to invoices" is a plain text link at the top-left of the toolbar, not a bottom-of-page button.
- Remove the bottom action row entirely (Print/Edit/Delete/Back) — all actions consolidate into the toolbar.

### 3.2 Status indicator
Replace the small grey "DRAFT" text with a colored badge (existing `data-*` badge variants):
- `draft` → neutral/grey
- `sent` → coral/amber (soft-tinted, not solid fill — per existing design system rule that badges must stay visually distinct from action buttons)
- `paid` → teal
- `overdue` → red
- `void` → muted/strikethrough treatment

Placed directly beside the invoice number (`INV-0011 · [SENT]`), not beneath it. Optional: a small horizontal stepper (Draft → Sent → Paid) beneath the badge, only for `draft`/`sent`/`overdue`/`paid` (not shown for `void`, which is a terminal branch, not a step).

### 3.3 The document
Rendered from the **same partial/template as the PDF/print view** so the two never drift apart. Visually: business letterhead block top-left, "Invoice" + number top-right, thin rule, Bill To + Issued/Due below, line items table, totals block right-aligned, payment details, legal footer.

- **Draft mode:** each editable region gets a subtle affordance on hover (e.g. dotted underline or a small pencil icon) indicating it's click-to-edit. Line items table gets an "Add line item" row at the bottom instead of a separate button below the table. No per-row Edit/Remove buttons sitting outside the table — the row itself becomes the edit target on click; Remove is a small icon within the row, revealed on hover.
- **Locked mode (sent/paid/overdue/void):** no hover affordances, no edit icons. If someone lands on `/edit` for a non-draft invoice directly (bookmarked URL, etc.), redirect to `#show` with a flash explaining the invoice is locked.

### 3.4 Activity strip
Below the document, a compact horizontal or vertical timeline: `Created → Sent (date) → Viewed (date, if trackable) → Paid (date)`. This is the one piece of real, non-redundant metadata worth a distinct zone. Collapsed/hidden for drafts (nothing has happened yet).

## 4. Bug fix (unrelated to layout, found in the current print template)

The print view currently outputs literal template syntax instead of evaluating it:

```
<# if @invoice.peppol_ready? %>
✓ PEPPOL-ready structured invoice
```

This needs to be corrected to valid ERB (`<%= if ... %>` / `<% if @invoice.peppol_ready? %> ... <% end %>` as appropriate) so the conditional actually evaluates instead of leaking into client-facing output.

## 5. CUBE CSS implementation notes

- New block: `.invoice-toolbar` (sticky, cluster layout, justify-content: space-between for primary vs. back-link, gap utility for secondary actions).
- New block: `.invoice-doc` for the document itself — shared between show (sent/paid/void) and the print stylesheet, so print styles and screen styles both key off the same block/element names.
- Reuse existing `.badge[data-status="..."]` pattern for status; add `overdue` and `void` variants if not already present in `colors.css` tokens.
- Editable-in-draft affordance can be a simple `[data-editable]` attribute selector with a `:hover` dotted-underline utility, rather than a new block.
- Overflow menu: reuse whatever disclosure/dropdown pattern already exists in the design system (or a `<details>`/`<summary>` native disclosure if nothing exists yet — keeps it dependency-free and consistent with the "simplicity" ethos of the app itself).
- Activity strip: a simple `.stack` or `.cluster` (Every Layout primitive) of small text rows, no new component needed.

## 6. Open questions for Reinis (not yet decided — flag before implementation)

1. **Void vs. Delete semantics:** confirm Void = "cancelled but number reserved" (audit trail intact, VID-safe) and Delete = only ever available for `draft` status (never touches an issued invoice number). If that's correct, Delete should never appear in the overflow menu for sent/paid/overdue/void — only Void does.
2. **"Viewed" tracking:** does the app currently track when a client opens the payment link/hosted invoice page? If not yet, the Activity strip should omit that row until it exists rather than showing a placeholder.
3. **Mark as paid:** is this manual (bank transfer reconciliation) or will it eventually be automatic via a payment integration? Affects whether "Mark as paid" needs a small form (amount, date) or is a single click.
