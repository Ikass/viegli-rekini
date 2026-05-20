require "test_helper"

class InvoiceVoidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:one)
    sign_in_as(@user)
    @invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-V1", issued_on: Date.current, due_on: Date.current + 14.days)
  end

  test "create transitions draft to void" do
    assert @invoice.draft?

    post invoice_invoice_voids_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.void?
  end

  test "create fails for already void invoice" do
    @invoice.update!(status: :void)

    post invoice_invoice_voids_path(@invoice)

    assert_redirected_to invoice_path(@invoice)
    assert @invoice.reload.void?
  end
end
