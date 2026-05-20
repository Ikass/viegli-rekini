require "test_helper"

class InvoicePaymentRecorderTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @client = clients(:one)
    @invoice = @account.invoices.create!(client: @client, invoice_number: "INV-P1", issued_on: Date.current, due_on: Date.current + 14.days, status: :sent)
  end

  test "records payment for a sent invoice" do
    assert @invoice.sent?

    result = InvoicePaymentRecorder.new.record_payment(invoice: @invoice)

    assert result.success?
    assert @invoice.reload.paid?
  end

  test "fails for draft invoices" do
    @invoice.update!(status: :draft)

    result = InvoicePaymentRecorder.new.record_payment(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.draft?
  end

  test "fails for paid invoices" do
    @invoice.update!(status: :paid)

    result = InvoicePaymentRecorder.new.record_payment(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.paid?
  end

  test "fails for void invoices" do
    @invoice.update!(status: :void)

    result = InvoicePaymentRecorder.new.record_payment(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.void?
  end
end
