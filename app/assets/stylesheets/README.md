# Reinis Design System

A light, first-principles CSS design system based on CUBE CSS methodology,
Andy Bell's modern reset, Every Layout primitives, and Utopia fluid type/space.
Built to work across Rails (Propshaft) and Bridgetown/Jekyll projects.

## Philosophy

- Semantic HTML first — classes only where they add clear value
- CUBE CSS: Composition → Utility → Block → Exception
- `@layer` for explicit cascade control — no `!important` needed
- OKLCH colour space throughout — perceptually uniform, predictable
- Fluid type and space via Utopia — no breakpoint juggling
- Every Layout primitives — intrinsic, responsive without media queries
- Dark mode built in via `prefers-color-scheme` + explicit `data-theme` overrides

## File Structure

```
styles/
├── main.css                  # Entry point — @layer declarations + @imports only
├── reset.css                 # Andy Bell's modern CSS reset (piccalil.li)
├── tokens/
│   ├── colors.css            # OKLCH palette + semantic aliases + dark mode
│   ├── typography.css        # Font families + Utopia fluid type scale
│   ├── spacing.css           # Utopia fluid space scale + container widths
│   └── shadows.css           # Elevation-based shadow scale
├── base/
│   ├── global.css            # Element-level defaults + sticky footer grid
│   ├── buttons.css           # Neutral <button> element defaults
│   └── forms.css             # Bare form element defaults (inputs, selects etc.)
├── layouts/
│   ├── container.css         # Max-width wrapper
│   ├── stack.css             # Vertical rhythm via gap (Every Layout)
│   ├── cluster.css           # Horizontal grouping, wraps (Every Layout)
│   ├── sidebar.css           # Fixed sidebar + fluid content (Every Layout)
│   └── grid.css              # Auto-fill responsive grid (Every Layout)
├── blocks/
│   ├── nav.css               # Main site navigation
│   ├── forms.css             # Field groups, hints, errors, form layout
│   ├── button.css            # .button with data-variant and data-size
│   ├── card.css              # .card with optional header/footer
│   ├── table.css             # .table for index/listing pages
│   ├── badge.css             # .badge for status indicators
│   ├── flash.css             # Rails flash messages
│   ├── footer.css            # Site footer
│   └── prose.css             # Long-form content styling
└── utilities/
    ├── flow.css              # .flow — margin-based prose rhythm
    ├── measure.css           # .measure — line length constraints
    └── a11y.css              # .sr-only, prefers-reduced-motion
```

## Cascade Layers

```css
@layer reset, tokens, base, layouts, blocks, utilities;
```

Utilities always win over blocks, blocks over base, base over tokens. Third-party
CSS dropped into a project without a layer declaration sits above all layers by
default — wrap it in `@layer third-party { }` if it causes conflicts.

## Using in a Project

1. Copy the `styles/` folder into your project's stylesheet directory
2. Link `main.css` as your stylesheet entry point
3. Customise tokens for your brand:
   - `tokens/colors.css` — swap OKLCH values in the raw palette section
   - `tokens/typography.css` — set `--font-base`, `--font-heading`, import web fonts
   - `tokens/spacing.css` — adjust `--container` default width if needed
4. Add or remove block imports in `main.css` as needed
5. Add project-specific blocks in `blocks/`

### Rails (Propshaft + importmaps)

Propshaft serves files as-is without bundling. The browser resolves `@import`
natively in development. In production Propshaft fingerprints filenames, which
can break `@import` path resolution — acceptable for internal/dev tools, revisit
with `cssbundling-rails` when shipping to production users.

```erb
<%# app/views/layouts/application.html.erb %>
<%= stylesheet_link_tag "application" %>
```

```css
/* app/assets/stylesheets/application.css */
/* paste contents of main.css here */
```

### Bridgetown / Jekyll

Use esbuild (already configured on most projects) with `@import` support:

```css
/* Entry point — esbuild resolves @imports */
@import "./tokens/colors.css";
@import "./tokens/typography.css";
/* etc. */
```

### Sticky Footer

Requires `<header>`, `<main>`, and `<footer>` as direct children of `<body>`.
The grid is set on `body` in `base/global.css`:

```css
body {
  display: grid;
  grid-template-rows: auto 1fr auto;
  min-height: 100dvh;
}
```

## Layout Classes

```html
<!-- Centred max-width wrapper -->
<div class="container">
<div class="container" data-size="sm">  <!-- xs | sm | md | lg | xl -->

<!-- Vertical stack with gap -->
<div class="stack">
<div class="stack" style="--stack-gap: var(--space-l)">

<!-- Horizontal cluster (wraps) -->
<div class="cluster">
<div class="cluster" data-justify="space-between">

<!-- Sidebar + fluid content -->
<div class="sidebar-layout">
  <aside>sidebar (fixed width)</aside>
  <main>content (fills rest)</main>
</div>

<!-- Auto responsive grid -->
<div class="grid">
<div class="grid" data-columns="3">  <!-- 2 | 3 | 4 -->
```

## Block Components

### Button

```html
<button class="button">Default</button>
<a href="..." class="button" data-variant="primary">Primary</a>
<button class="button" data-variant="secondary">Secondary</button>
<button class="button" data-variant="ghost">Ghost</button>
<button class="button" data-variant="danger">Danger</button>
<button class="button" data-size="sm">Small</button>
<button class="button" data-size="lg">Large</button>
<button class="button" data-width="full">Full width</button>
```

### Card

```html
<article class="card">
  <header>
    <h2>Title</h2>
  </header>
  <div class="flow">
    <p>Body content</p>
  </div>
  <footer>
    <a href="..." class="button" data-variant="primary">Action</a>
  </footer>
</article>

<!-- Variants -->
<article class="card" data-variant="flat">
<article class="card" data-variant="raised">
<article class="card" data-variant="ghost">
<article class="card" data-interactive>  <!-- hover lift effect -->
```

### Table

```html
<div class="table-wrapper">
  <table class="table">
    <thead>
      <tr>
        <th>Name</th>
        <th class="col-numeric">Amount</th>
        <th class="col-actions">Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>...</td>
        <td class="col-numeric">€100.00</td>
        <td class="col-actions">...</td>
      </tr>
      <tr class="table-empty"><td colspan="3">No records found</td></tr>
    </tbody>
  </table>
</div>

<!-- Variants -->
<table class="table" data-variant="striped">
<table class="table" data-variant="bordered">
```

### Badge

```html
<!-- Invoice statuses -->
<span class="badge" data-status="draft">Draft</span>
<span class="badge" data-status="sent">Sent</span>
<span class="badge" data-status="paid">Paid</span>
<span class="badge" data-status="void">Void</span>

<!-- General variants -->
<span class="badge" data-variant="success">Active</span>
<span class="badge" data-variant="warning">Pending</span>
<span class="badge" data-variant="error">Failed</span>
<span class="badge" data-variant="neutral">Archived</span>

<!-- In Rails ERB -->
<span class="badge" data-status="<%= invoice.status %>">
  <%= invoice.status.humanize %>
</span>
```

### Flash messages (Rails)

```erb
<%# In layout, just inside <main> or after <header> %>
<% flash.each do |type, message| %>
  <p class="flash" data-type="<%= type %>" role="<%= type == 'notice' ? 'status' : 'alert' %>">
    <%= message %>
  </p>
<% end %>
```

Keys: `notice` (green), `alert` (amber), `error` (red), `info` (blue).

### Prose

```html
<div class="prose">
  <h2>...</h2>
  <p>...</p>
</div>

<!-- Full width (no measure constraint) -->
<div class="prose" data-width="full">
```

### Forms

```html
<!-- Rails form helpers work unstyled — <p> wrappers styled automatically -->
<!-- Explicit field group -->
<div class="field">
  <label for="name">Name</label>
  <input type="text" id="name" name="name">
  <span class="hint">Optional hint text</span>
  <span class="error">Validation error</span>
</div>

<!-- Inline fields -->
<div class="fields-inline">
  <div class="field">...</div>
  <div class="field">...</div>
</div>

<!-- Form actions row -->
<div class="form-actions">
  <button class="button" data-variant="primary">Save</button>
  <a href="..." class="button" data-variant="ghost">Cancel</a>
</div>
```

## Theming

System dark mode is automatic via `prefers-color-scheme`.

Override on any element with `data-theme` — independent of system preference:

```html
<section data-theme="dark">...</section>
<section data-theme="light">...</section>
<section data-theme="brand">...</section>
```

## Colour Tokens

Always use semantic aliases in components, never raw palette tokens directly.

```css
/* Surfaces */
var(--color-surface-base)      /* page background */
var(--color-surface-raised)    /* cards, nav */
var(--color-surface-overlay)   /* hover states, inset */

/* Text */
var(--color-text)              /* primary text */
var(--color-text-muted)        /* secondary text */
var(--color-text-subtle)       /* placeholders, captions */
var(--color-text-invert)       /* text on dark/brand backgrounds */

/* Brand */
var(--color-brand)
var(--color-brand-hover)
var(--color-brand-text)        /* text colour on brand background */

/* Borders */
var(--color-border)
var(--color-border-focus)

/* States */
var(--color-success)
var(--color-warning)
var(--color-error)
var(--color-info)
```

To customise colours, edit only the raw palette section at the top of
`tokens/colors.css`. The semantic aliases cascade from there automatically,
including dark mode and `data-theme` overrides.

## Type Scale Tokens

```css
var(--step--2)   /* xs  — captions, labels */
var(--step--1)   /* sm  — secondary text */
var(--step-0)    /* base — body copy */
var(--step-1)    /* md  — lead paragraphs */
var(--step-2)    /* lg  — h4 */
var(--step-3)    /* xl  — h3 */
var(--step-4)    /* 2xl — h2 */
var(--step-5)    /* 3xl — h1 */
```

## Space Scale Tokens

```css
var(--space-3xs)    /* tightest */
var(--space-2xs)
var(--space-xs)
var(--space-s)
var(--space-m)      /* default component gap */
var(--space-l)
var(--space-xl)
var(--space-2xl)
var(--space-3xl)    /* loosest */

/* Paired values — fluid range between two steps */
var(--space-s-m)
var(--space-m-l)
var(--space-l-xl)
/* etc. */

/* Semantic aliases */
var(--gutter)           /* column gap */
var(--section-padding)  /* section top/bottom padding */
var(--component-gap)    /* gap between stacked components */
```

## Regenerating the Type/Space Scale

Visit https://utopia.fyi with these inputs:
- Min viewport: 375px, Max viewport: 1400px
- Min font size: 16px, Max font size: 20px
- Type scale: Minor Third (1.200)

Paste the generated `clamp()` values into `tokens/typography.css`
and `tokens/spacing.css`. Token names stay the same — nothing else changes.
