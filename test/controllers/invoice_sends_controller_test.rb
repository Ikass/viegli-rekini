require "test_helper"

class InvoiceSendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:one)
    sign_in_as(@user)
    @invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-S1", issued_on: Date.current, due_on: Date.current + 14.days)
  end

  test "create transitions draft to sent" do
    assert @invoice.draft?

    post invoice_invoice_sends_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.sent?
  end

  test "create fails for non-draft invoice" do
    @invoice.update!(status: :sent)

    post invoice_invoice_sends_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.sent?
  end
end
