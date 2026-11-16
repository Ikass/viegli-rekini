# frozen_string_literal: true

module ApplicationHelper
  def vat_rate_percentage(rate)
    display = rate.to_i == rate ? rate.to_i : rate
    "#{display}%"
  end

  def invoice_number_or_draft(invoice)
    invoice.invoice_number.presence || t("enums.invoice_status.draft")
  end

  def invoice_status_label(status)
    t("enums.invoice_status.#{status}", default: status.to_s.humanize)
  end

  def client_delivery_channel_label(channel)
    t("enums.client_delivery_channel.#{channel}", default: channel.to_s.humanize)
  end

  def client_vat_regime_label(regime)
    t("enums.client_vat_regime.#{regime}", default: regime.to_s.humanize)
  end

  def unit_code_label(code)
    t("enums.unit_codes.#{code}", default: code)
  end

  def tax_category_label(code)
    t("enums.tax_categories.#{code}", default: code)
  end

  def short_tax_category_label(code)
    t("enums.short_tax_categories.#{code}", default: code)
  end
end
