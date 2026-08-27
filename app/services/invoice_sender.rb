# frozen_string_literal: true

class InvoiceSender
  SELLER_REQUIRED_FIELDS = %i[company_name registration_number address city postal_code country bank_name bank_account].freeze

  Result = Struct.new(:success, :invoice, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def send_invoice(invoice:)
    return Result.new(success: false, invoice: invoice, error: "Invoice cannot be sent from #{invoice.status} status.") unless invoice.draft?

    missing = missing_legal_fields(invoice)
    if missing.any?
      return Result.new(success: false, invoice: invoice, error: "Cannot send invoice — missing: #{missing.join(", ")}.")
    end

    invoice.update!(status: :sent, sent_at: Time.current)
    Result.new(success: true, invoice: invoice)
  end

  private

  def missing_legal_fields(invoice)
    missing = []

    account = invoice.account
    SELLER_REQUIRED_FIELDS.each do |field|
      missing << field.to_s.humanize if account.public_send(field).blank?
    end

    missing << "Line items" if invoice.line_items.empty?
    invoice.line_items.each_with_index do |item, index|
      missing << "Unit code for line #{index + 1}" if item.unit_code.blank?
      missing << "Tax category for line #{index + 1}" if item.tax_category_code.blank?
    end

    missing
  end
end
