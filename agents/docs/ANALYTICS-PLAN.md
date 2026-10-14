# Analytics & Monitoring Plan — Viegli-Rēķini

> **Status:** planned 2026-10-12. Keep it simple: cookie-less, first-party where possible, no
> invoice data in third-party tools. The Cloudflare Web Analytics layer is **built** (2026-10-12 —
> see `notes/cloudflare-web-analytics-setup.md`) and error tracking is **built** (2026-10-14 — see
> §3); everything else below is planned.

DNS is at nic.lv, so Cloudflare runs in manual-snippet mode with no DNS change.

## Decisions

| Layer | Tool | Where | Status |
| --- | --- | --- | --- |
| Public page traffic | Cloudflare Web Analytics (manual JS snippet) | Public/marketing layout only | **Built 2026-10-12** (see `notes/cloudflare-web-analytics-setup.md`) |
| In-app product events | Ahoy + Blazer | Inside the app, primary SQLite DB | Next |
| Error tracking | Sentry (EU region) | App-wide | **Built 2026-10-14** |
| Background jobs | `mission_control-jobs` | `/admin`, behind admin auth | When PDF/XML generation moves to jobs |
| Uptime | UptimeRobot or Better Stack on `/up` | External | Do now (5 minutes) |
| Public page traffic (alternative) | Umami self-hosted via Kamal | Accessory on the VPS | Only if Cloudflare proves too limited |

## 1. Cloudflare Web Analytics (public pages)

- Free, no personal data collected, no hosting needed.
- Currently fires on the public entry point only (`/session/new`), not the authenticated app.
- Limits: no custom events, no UTM or query-string tracking, blocked by ad blockers, unsampled
  data for 7 days then aggregated to about 10%, 6 months of history.
- Implementation details are in `notes/cloudflare-web-analytics-setup.md`.

## 2. Ahoy + Blazer (in-app product analytics)

Purpose: measure activation, i.e. how fast a new user gets to a sent invoice. This is the evidence
for the "ease of creating invoices" positioning and for the per-invoice pricing decision.

Setup:
- Gems: `ahoy_matey`, `blazer`. Run `rails g ahoy:install` and `rails g blazer:install`, then migrate.
- `config/initializers/ahoy.rb`:
  ```ruby
  Ahoy.api = false
  Ahoy.cookies = :none
  Ahoy.mask_ips = true
  Ahoy.server_side_visits = :when_needed
  ```
- Keep it in the primary SQLite DB at first so Blazer can join events to `users` and `invoices`.
  Split to a second database (`connects_to` on `Ahoy::Visit` and `Ahoy::Event`) only if the table
  grows large.
- Mount Blazer at `/admin/blazer` behind the admin check or basic auth from env vars.

Events (server-side, `ahoy.track "name", id: record.id`):
- `signed_up`
- `client_created`
- `catalog_item_created`
- `invoice_created`
- `invoice_pdf_downloaded`
- `invoice_sent`
- `einvoice_xml_generated`

Rules: IDs only in properties. No amounts, names, IBANs or VAT numbers.

Starter Blazer queries:
```sql
-- Activation funnel, last 30 days
SELECT name, COUNT(DISTINCT user_id) AS users
FROM ahoy_events
WHERE time > date('now','-30 days')
GROUP BY name ORDER BY users DESC;

-- Hours from signup to first invoice
SELECT u.id,
  ROUND((julianday(MIN(e.time)) - julianday(u.created_at)) * 24, 1) AS hours
FROM users u
JOIN ahoy_events e ON e.user_id = u.id AND e.name = 'invoice_created'
GROUP BY u.id;
```

Privacy: mention first-party product analytics in the privacy policy.

## 3. Error tracking

> **As built (2026-10-14):** Sentry cloud (EU region — DSN host is `…ingest.de.sentry.io`) with
> `sentry-ruby` 7.x + `sentry-rails` 7.x.

- `config/initializers/sentry.rb`: DSN read from credentials (`sentry.dsn`), `send_default_pii = false`,
  `traces_sample_rate = 0.0` (error tracking only, no performance tracing), `enabled_environments`
  limited to `production`, and a `before_send` hook → `ScrubInvoiceData`.
- `lib/scrub_invoice_data.rb`: strips IBANs, VAT numbers, bank details, client/company names and
  contact PII from `extra`, breadcrumbs, query strings, and exception messages before send.
- `config/initializers/filter_parameter_logging.rb` also filters those invoice fields from request
  params (covers Rails logs and Sentry request data alike).
- GlitchTip (self-hosted) remains the fallback if the free tier or EU residency ever becomes a
  constraint, but it means running another service.

**Deploy + verify:** `bin/kamal deploy`, then
`bin/kamal app exec --reuse "bin/rails runner 'Sentry.capture_message(\"test message\")'"` and
confirm the event lands in the Sentry project (EU region).

## 4. Solid Queue dashboard

- Add `mission_control-jobs`, mounted under the admin namespace with auth.
- Useful once PDF and XML generation run in the background and failed jobs need to be visible.

## 5. Uptime

- Free UptimeRobot or Better Stack check on Rails' `/up` endpoint, with email alerts.

## 6. Umami (parked alternative)

Use only if Cloudflare Web Analytics turns out too limited for the public pages.

- Needs Postgres, so two Kamal accessories (`umami-db`, `umami`).
- Sketch for `config/deploy.yml`:
  ```yaml
  accessories:
    umami-db:
      image: postgres:16
      host: <VPS IP>
      env:
        clear:
          POSTGRES_DB: umami
          POSTGRES_USER: umami
        secret:
          - POSTGRES_PASSWORD
      directories:
        - umami-db:/var/lib/postgresql/data
    umami:
      image: ghcr.io/umami-software/umami:postgresql-latest
      host: <VPS IP>
      env:
        secret:
          - DATABASE_URL   # postgresql://umami:PASS@<service>-umami-db:5432/umami
          - APP_SECRET
      proxy:
        host: stats.viegli-rekini.lv
        app_port: 3000
        ssl: true
  ```
- Add a DNS A record for `stats.viegli-rekini.lv` at nic.lv. Boot with
  `kamal accessory boot umami-db umami`. Accessory `proxy:` needs a recent Kamal 2.x.
- Change the default admin password immediately.
- Check VPS RAM first: Umami plus Postgres needs roughly 300-500 MB.

## Later: RentForge

- RentForge's planned analytics (tied to form submissions, leads and scoring) can eventually replace
  the public-page tracker, with viegli-rekini's landing page as a first real tenant. Swapping is a
  one-line script change.
- Uptime monitoring is also on the RentForge roadmap.
- Ahoy/Blazer, error tracking and Mission Control stay per-app and are not RentForge features.
