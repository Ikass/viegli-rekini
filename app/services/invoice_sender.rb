# frozen_string_literal: true

class InvoiceSender
  Result = Struct.new(:success, :invoice, keyword_init: true) do
    def success?
      success
    end
  end

  def send_invoice(invoice:)
    return Result.new(success: false, invoice: invoice) unless invoice.draft?

    invoice.update!(status: :sent)
    Result.new(success: true, invoice: invoice)
  end
end
