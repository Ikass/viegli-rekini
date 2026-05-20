require "test_helper"

class InvoiceSenderTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @client = clients(:one)
    @invoice = @account.invoices.create!(client: @client, invoice_number: "INV-S1", issued_on: Date.current, due_on: Date.current + 14.days)
  end

  test "sends a draft invoice" do
    assert @invoice.draft?

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert result.success?
    assert @invoice.reload.sent?
  end

  test "fails for non-draft invoices" do
    @invoice.update!(status: :sent)

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.sent?
  end

  test "fails for paid invoices" do
    @invoice.update!(status: :paid)

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.paid?
  end

  test "fails for void invoices" do
    @invoice.update!(status: :void)

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.void?
  end
end
