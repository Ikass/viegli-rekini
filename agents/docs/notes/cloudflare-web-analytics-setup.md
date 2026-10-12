# Cloudflare Web Analytics — public pages

> Added 2026-10-12. Client-side traffic counting for the public entry point, so we can see whether
> anyone besides the owner visits `viegli-rekini.lv` (e.g. recruiters following the CV link).
> Not a product feature — no custom events, no query-string/UTM tracking.

## What's in place

- **Partial:** `app/views/shared/_cloudflare_analytics.html.erb` — renders the Cloudflare beacon
  (`static.cloudflareinsights.com/beacon.min.js`) with the site token.
- **Rendered from:** `app/views/sessions/new.html.erb` only — i.e. the login screen (`/session/new`),
  the sole public entry point. The authenticated app layouts do **not** load it, so invoice data
  stays out of third-party analytics.
- **Token:** Rails credentials at `cloudflare.web_analytics_token` (single
  `config/credentials.yml.enc`; the app has no ENV-secret pattern). `bin/rails credentials:edit`.

## Why these choices

- **Not the `auth` layout:** the auth layout also serves password-reset and (disabled) sign-up.
  Rendered in the `sessions/new` view instead, so scope is exactly `/session/new` for now. Widen to
  the whole `auth` layout later by moving the `render` there.
- **Production only:** the `Rails.env.production?` guard keeps dev/test traffic uncounted.
- **No `nonce` attribute:** CSP is disabled (`config/initializers/content_security_policy.rb` is
  fully commented out) and Cloudflare's *manual* embed needs no nonce.
- **No `integrity` (SRI):** Cloudflare doesn't version-pin the manual beacon; SRI would break on
  their next update.
- **`data-turbo-eval="false"`** stops Turbo re-running the script across visits.
- **Site is NOT proxied through Cloudflare** (DNS at nic.lv) → manual JS snippet, not automatic
  injection. Do not change DNS.

## If CSP is ever enabled

Add to the policy, then trial with `content_security_policy_report_only = true`:

```ruby
policy.script_src  *policy.script_src,  "https://static.cloudflareinsights.com"
policy.connect_src *policy.connect_src, "https://cloudflareinsights.com"
```

Also leave the referrer policy permissive enough to send `Referer` (browser default
`strict-origin-when-cross-origin` is fine — do **not** set `no-referrer`).

## Verify after deploy

1. Load `/session/new` with ad-block off: `beacon.min.js` returns 200, and a POST to
   `cloudflareinsights.com/cdn-cgi/rum` fires.
2. Turbo-navigate and confirm the script isn't injected twice.
3. Confirm authenticated app pages load no beacon.
4. Data shows in the Cloudflare dashboard within minutes.

## Limitations (expected, don't work around)

- Ad blockers block the beacon → numbers undercount.
- No custom events / UTM / query strings. Use Ahoy inside the app for events.
- Unsampled 7 days, then ~10% aggregation; 6-month dashboard history.
- One beacon per page; ~10 non-proxied sites per account.
- **No privacy-policy line added** — the app has no privacy policy page yet. Revisit if one is
  created (name Cloudflare Web Analytics as processor for aggregate public-page traffic).
