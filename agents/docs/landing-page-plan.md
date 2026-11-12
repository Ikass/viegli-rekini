# Plan: English landing page (homepage) for viegli-rēķini

Status: approved, implementing 2026-11-12. Owner: Reinis. Executor: OpenCode.

First slice of `i18n-plan.md` Phase 6 (public pages). Builds the *English* landing
page at `/en` from the design mockup in `agents/designs/Landing page, English draft-html/`.
The Latvian page at `/` follows later, when the LV copy is supplied.

## Source of truth

- **Design:** `agents/designs/Landing page, English draft-html/Main.dc.html` (reference
  mockup — replicate the values, don't copy the markup).
- **i18n rules:** `agents/docs/i18n-plan.md` (conventions, locale handling).

## Decisions locked

- App home moves to **`/dashboard`**; the public landing owns `/`.
- **English at `/en`; `/` → 302 redirect to `/en`** until the LV copy exists.
- Primary CTA "Create your first invoice" → **`demo_session_path`** (POST — render as
  `button_to`, not a link). Sign-up stays disabled.
- **Reconcile into one design system:** adopt the landing palette + IBM Plex into the
  shared tokens; the app and landing share one token set.
- **Fonts:** IBM Plex Sans (body/UI) + IBM Plex Serif (headings), **self-hosted**,
  latin + latin-ext subsets (Latvian diacritics).
- **Brand:** `ViegliRēķini` (no hyphen, no space) — `APP_NAME` in `application.rb`.
  Domain stays `viegli-rekini.lv` for now; `vieglirekini.lv` is a post-launch move
  (would touch `production.rb` host auth + `deploy.yml` — out of scope here).
- **Pricing:** render with the mockup's per-invoice draft + `[€0.00]` / `[N] free
  invoices` placeholders (do not publish the "TO BE DECIDED" note).
- **Founder block:** `app/assets/images/reinis-profile-800w.webp` (~180px circle),
  email `reinis@grittypublishing.com`.
- **Footer:** `SIA "Gritty Publishing" · Reg. no. 40203365593`.
- **FAQ:** bracketed `[...]` answers left as-is for now.
- **Legal links** (`#privacy` / `#terms` / `#contact`): no pages exist yet — keep the
  anchor links but they will 404/do nothing until the pages are built.

## Phases

### A. i18n foundation (minimal)
- `config/application.rb`: `available_locales = [:lv, :en]`. Keep `default_locale = :en`
  for now (flips to `:lv` in i18n-plan Phase 3, once LV translations exist — flipping
  now would break the still-unlocalized app pages). Add a comment to that effect.
- `ApplicationController`: `around_action :switch_locale` reading `params[:locale]`,
  defaulting to `I18n.default_locale`.
- `<html lang>` from `I18n.locale` in all layouts (today hardcoded `en`).
- `config/locales/landing.en.yml` (+ empty `landing.lv.yml` for later).

### B. Routing
- `LandingController#show`, `allow_unauthenticated_access`.
- `get "/", to: redirect("/en", status: 302)` then `scope "(:locale)", locale: /en/`
  with `get "/" => "landing#show", as: :landing`.
- `root "landing#show"`; `get "/dashboard" => "dashboards#show"`.
- `/` (no locale) redirects: signed-in users → `/dashboard`, guests → `/en`.
- Migrate the five `root_path` call sites → `dashboard_path`:
  `authentication.rb:38`, `accounts_controller.rb:12`, `accounts/edit.html.erb:111`,
  `application.html.erb:25` and `:51`.

### C. Brand rename
- `APP_NAME = "ViegliRēķini"` (display-only, propagates through title/nav/footer/login).

### D. Landing markup (English)
- New `landing` layout (no app chrome), includes `shared/cloudflare_analytics`.
- ERB sections mirroring the mockup, copy via `t(".key")` from `landing.en.yml`:
  top strip, nav, hero, 3-step illustration (pure HTML/CSS), contrast block, founder
  note (photo + email), "What it does" (6 cards), "Built around Latvian law", pricing,
  FAQ (`<details>`), closing CTA, footer.

### E. Styles
- Self-host IBM Plex woff2 (latin + latin-ext) in `app/assets/fonts/`.
- Update `tokens/colors.css` raw palette + semantic aliases to the landing values
  (coral `#C8452B`, teal `#0E4F52`, cream `#FBF5E6`, ink `#1F2421`, muted `#5A5F58`,
  line `#E7DEC8`), expressed in OKLCH per the file convention.
- Update `tokens/typography.css` with the Plex families.
- New `blocks/landing.css` for the marketing sections; responsive from 375px.

### F. Latvian copy (later)
- Fill `landing.lv.yml` (written by Reinis, not machine-translated); flip `/` from
  redirect to a real page; add `hreflang`/canonical + language switcher.

### G. QA
- 375px both languages; `bin/ci`; `AGENTS.md`/`ARCHITECTURE.md` i18n section.

## Out of scope (this pass)
Full app-wide i18n extraction (i18n-plan Phases 2–5), legal pages, the `vieglirekini.lv`
domain move, and filling in the pricing numbers / FAQ answers.
