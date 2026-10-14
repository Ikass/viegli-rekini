# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [ :active_support_logger ]
  config.enabled_environments = %w[production]

  # GDPR — Sentry's template defaults this to `true`; we override to false so
  # user IPs, cookies, and request bodies never leave the server. See
  # agents/docs/ANALYTICS-PLAN.md §3.
  config.send_default_pii = false

  # Error tracking only. Performance tracing stays off (0.0) to keep event
  # volume and the data surface small — traces can carry SQL and param data.
  config.traces_sample_rate = 0.0

  # Safety net: strip invoice/contact PII (IBAN, VAT, client names) from
  # `extra`, breadcrumbs, query strings, and exception messages before sending.
  config.before_send = ->(event, _hint) { ScrubInvoiceData.call(event) }
end
