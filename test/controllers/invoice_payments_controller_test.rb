require "test_helper"

class InvoicePaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:one)
    sign_in_as(@user)
    @invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-P1", issued_on: Date.current, due_on: Date.current + 14.days, status: :sent)
  end

  test "create transitions sent to paid" do
    assert @invoice.sent?

    post invoice_invoice_payments_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.paid?
  end

  test "create fails for non-sent invoice" do
    @invoice.update!(status: :draft)

    post invoice_invoice_payments_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.draft?
  end
end
