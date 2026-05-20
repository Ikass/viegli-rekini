require "test_helper"

class InvoiceVoiderTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @client = clients(:one)
    @invoice = @account.invoices.create!(client: @client, invoice_number: "INV-V1", issued_on: Date.current, due_on: Date.current + 14.days)
  end

  test "voids a draft invoice" do
    assert @invoice.draft?

    result = InvoiceVoider.new.void_invoice(invoice: @invoice)

    assert result.success?
    assert @invoice.reload.void?
  end

  test "voids a sent invoice" do
    @invoice.update!(status: :sent)

    result = InvoiceVoider.new.void_invoice(invoice: @invoice)

    assert result.success?
    assert @invoice.reload.void?
  end

  test "voids a paid invoice" do
    @invoice.update!(status: :paid)

    result = InvoiceVoider.new.void_invoice(invoice: @invoice)

    assert result.success?
    assert @invoice.reload.void?
  end

  test "fails for already void invoices" do
    @invoice.update!(status: :void)

    result = InvoiceVoider.new.void_invoice(invoice: @invoice)

    assert_not result.success?
    assert @invoice.reload.void?
  end
end
