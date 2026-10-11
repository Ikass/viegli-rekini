module ApplicationHelper
  def vat_rate_percentage(rate)
    display = rate.to_i == rate ? rate.to_i : rate
    "#{display}%"
  end

  def invoice_number_or_draft(invoice)
    invoice.invoice_number.presence || "Draft"
  end
end
