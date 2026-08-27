# frozen_string_literal: true

class InvoiceVoider
  Result = Struct.new(:success, :invoice, keyword_init: true) do
    def success?
      success
    end
  end

  def void_invoice(invoice:)
    return Result.new(success: false, invoice: invoice) if invoice.void?

    invoice.update!(status: :void, voided_at: Time.current)
    Result.new(success: true, invoice: invoice)
  end
end
