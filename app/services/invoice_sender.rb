# frozen_string_literal: true

class InvoiceSender
  SELLER_REQUIRED_FIELDS = %i[company_name registration_number address city postal_code country bank_name bank_account].freeze

  Result = Struct.new(:success, :invoice, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def send_invoice(invoice:)
    unless invoice.draft?
      return Result.new(success: false, invoice: invoice,
        error: I18n.t("services.invoice_sender.cannot_send_from", status: invoice.status))
    end

    missing = missing_legal_fields(invoice)
    if missing.any?
      return Result.new(success: false, invoice: invoice,
        error: I18n.t("services.invoice_sender.missing", missing: missing.join(", ")))
    end

    invoice.transaction do
      number = invoice.invoice_number || InvoiceSequence.next_for!(invoice.account)
      invoice.update!(invoice_number: number, status: :sent, sent_at: Time.current)
    end

    Result.new(success: true, invoice: invoice)
  end

  private

  def missing_legal_fields(invoice)
    missing = []

    account = invoice.account
    SELLER_REQUIRED_FIELDS.each do |field|
      missing << Account.human_attribute_name(field) if account.public_send(field).blank?
    end

    missing << I18n.t("services.invoice_sender.line_items") if invoice.line_items.empty?
    invoice.line_items.each_with_index do |item, index|
      missing << I18n.t("services.invoice_sender.unit_code_for_line", line: index + 1) if item.unit_code.blank?
      missing << I18n.t("services.invoice_sender.tax_category_for_line", line: index + 1) if item.tax_category_code.blank?
    end

    missing
  end
end
