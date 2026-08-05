# frozen_string_literal: true

require "test_helper"

class InvoiceSendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.account.update!(
      company_name: "SIA Test",
      registration_number: "LV40001234567",
      address: "Brīvības iela 100",
      city: "Rīga",
      postal_code: "LV-1001",
      country: "Latvija",
      bank_name: "Swedbank",
      bank_account: "LV12HABA0001234567890"
    )
    @client = clients(:one)
    sign_in_as(@user)
    @invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-S1", issued_on: Date.current, due_on: Date.current + 14.days)
    @invoice.line_items.create!(description: "Test", quantity: 1, unit_code: "C62", unit_price_cents: 1000, tax_category_code: "S", vat_rate: 21)
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
