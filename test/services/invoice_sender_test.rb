# frozen_string_literal: true

require "test_helper"

class InvoiceSenderTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @account.update!(
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
    @invoice = @account.invoices.create!(client: @client, invoice_number: "INV-S1", issued_on: Date.current, due_on: Date.current + 14.days)
    @invoice.line_items.create!(description: "Test item", quantity: 1, unit_code: "C62", unit_price_cents: 1000, tax_category_code: "S", vat_rate: 21)
  end

  test "sends a draft invoice" do
    assert @invoice.draft?

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert result.success?
    assert @invoice.reload.sent?
    assert_not_nil @invoice.sent_at
  end

  test "fails for non-draft invoices" do
    @invoice.update!(status: :sent)

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert_equal "Invoice cannot be sent from sent status.", result.error
    assert @invoice.reload.sent?
  end

  test "fails for paid invoices" do
    @invoice.update!(status: :paid)

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert_equal "Invoice cannot be sent from paid status.", result.error
    assert @invoice.reload.paid?
  end

  test "fails for void invoices" do
    @invoice.update!(status: :void)

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert_equal "Invoice cannot be sent from void status.", result.error
    assert @invoice.reload.void?
  end

  test "fails when seller legal fields are missing" do
    @account.update!(
      company_name: nil,
      registration_number: nil,
      address: nil,
      city: nil,
      postal_code: nil,
      country: nil,
      bank_name: nil,
      bank_account: nil
    )

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert_includes result.error, "Cannot send invoice — missing"
    assert_includes result.error, "Company name"
    assert_includes result.error, "Registration number"
    assert_includes result.error, "Address"
    assert_includes result.error, "Bank account"
  end

  test "fails when invoice has no line items" do
    @invoice.line_items.destroy_all

    result = InvoiceSender.new.send_invoice(invoice: @invoice)

    assert_not result.success?
    assert_includes result.error, "Line items"
  end
end
