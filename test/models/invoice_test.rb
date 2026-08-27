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

  test "vat_regime_note returns nil when issuer has no VAT number" do
    account = accounts(:one)
    client = clients(:one)
    client.update_column(:vat_regime, 1) # reverse_charge

    invoice = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_nil invoice.vat_regime_note
  end

  test "vat_regime_note returns note when issuer is VAT-registered and client has special regime" do
    account = accounts(:one)
    account.update_column(:vat_number, "LV40001234567")
    client = clients(:one)
    client.update_column(:vat_regime, 1) # reverse_charge

    invoice = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_match(/Reverse charge/i, invoice.vat_regime_note)
  end

  test "vat_regime_note returns nil for standard regime even when issuer is VAT-registered" do
    account = accounts(:one)
    account.update_column(:vat_number, "LV40001234567")
    client = clients(:one)
    client.update_column(:vat_regime, 0) # standard

    invoice = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_nil invoice.vat_regime_note
  end

  test "overdue? is true for sent invoices past their due date" do
    invoice = accounts(:one).invoices.create!(
      client: clients(:one),
      issued_on: Date.current - 30,
      due_on: Date.current - 1,
      status: :sent
    )

    assert invoice.overdue?
    assert_equal "overdue", invoice.display_status
  end

  test "overdue? is false for sent invoices not yet due" do
    invoice = accounts(:one).invoices.create!(
      client: clients(:one),
      issued_on: Date.current,
      due_on: Date.current + 30,
      status: :sent
    )

    assert_not invoice.overdue?
    assert_equal "sent", invoice.display_status
  end

  test "overdue? is false for draft and paid invoices regardless of due date" do
    draft = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current - 30, due_on: Date.current - 1, status: :draft)
    paid = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current - 30, due_on: Date.current - 1, status: :paid)

    assert_not draft.overdue?
    assert_not paid.overdue?
    assert_equal "draft", draft.display_status
    assert_equal "paid", paid.display_status
  end
end
