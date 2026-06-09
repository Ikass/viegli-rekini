# frozen_string_literal: true

require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "generates invoice number on create using account prefix and padding" do
    account = accounts(:one)
    client = clients(:one)
    invoice = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_equal "INV-0001", invoice.invoice_number
  end

  test "increments invoice number sequentially" do
    account = accounts(:one)
    client = clients(:one)

    first = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    second = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_equal "INV-0001", first.invoice_number
    assert_equal "INV-0002", second.invoice_number
  end
end
