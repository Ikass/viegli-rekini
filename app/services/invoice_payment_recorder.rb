# frozen_string_literal: true

class InvoicePaymentRecorder
  Result = Struct.new(:success, :invoice, keyword_init: true) do
    def success?
      success
    end
  end

  def record_payment(invoice:)
    return Result.new(success: false, invoice: invoice) unless invoice.sent?

    invoice.update!(status: :paid)
    Result.new(success: true, invoice: invoice)
  end
end
