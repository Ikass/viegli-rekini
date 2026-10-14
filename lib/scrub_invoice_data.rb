# frozen_string_literal: true

# Strips invoice and contact PII from a Sentry event before it leaves the
# server. Request params are already covered by Rails' `filter_parameters`
# (config/initializers/filter_parameter_logging.rb); this is the safety net for
# anything that ends up in `extra`, breadcrumbs, the query string, or an
# exception message. Mirrors ANALYTICS-PLAN.md §3 — no IBANs, VAT numbers, or
# client names in third-party tools.
module ScrubInvoiceData
  SENSITIVE_KEYS = %w[
    iban
    bank_account
    bank_swift
    bank_name
    bic
    swift
    vat_number
    vat
    registration_number
    reg_number
    client_name
    company_name
    email
    email_address
    password
    password_digest
    token
    secret
  ].freeze

  # ISO 13616 IBAN: two-letter country code, two check digits, then 11–30
  # alphanumeric characters (15–34 total). Over-redacting an innocent token is
  # the safe direction; missing a real IBAN is not.
  IBAN_PATTERN = /\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/

  module_function

  # Entry point from the Sentry `before_send` hook. Mutates and returns `event`.
  def call(event)
    scrub_hash(event.extra) if event.extra.present?
    scrub_request(event.request) if event.request
    scrub_breadcrumbs(event.breadcrumbs)
    scrub_exceptions(event)
    scrub_message(event)
    event
  end

  def scrub_hash(hash)
    return hash unless hash.is_a?(Hash)

    hash.each do |key, value|
      if sensitive_key?(key)
        hash[key] = "[FILTERED]"
      elsif value.is_a?(Hash)
        scrub_hash(value)
      elsif value.is_a?(Array)
        value.each_with_index do |item, index|
          value[index] = scrub_string(item) if item.is_a?(String)
          scrub_hash(item) if item.is_a?(Hash)
        end
      elsif value.is_a?(String)
        hash[key] = scrub_string(value)
      end
    end

    hash
  end

  def scrub_string(value)
    value.gsub(IBAN_PATTERN, "[FILTERED]")
  end

  def sensitive_key?(key)
    SENSITIVE_KEYS.include?(key.to_s.downcase)
  end

  def scrub_request(request)
    scrub_hash(request.data) if request.respond_to?(:data) && request.data.present?
    if request.respond_to?(:query_string) && request.query_string.present?
      request.query_string = scrub_string(request.query_string)
    end
    scrub_hash(request.cookies) if request.respond_to?(:cookies) && request.cookies.present?
  end

  def scrub_breadcrumbs(breadcrumbs)
    return unless breadcrumbs

    breadcrumbs.each do |crumb|
      scrub_hash(crumb.data) if crumb.respond_to?(:data) && crumb.data.present?
    end
  end

  def scrub_exceptions(event)
    return unless event.respond_to?(:exception) && event.exception

    event.exception.values.each do |exception|
      next unless exception.respond_to?(:value) && exception.value.present?

      exception.value = scrub_string(exception.value)
    end
  end

  def scrub_message(event)
    return unless event.respond_to?(:message) && event.message.present?

    event.message = scrub_string(event.message)
  end
end
