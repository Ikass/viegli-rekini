# frozen_string_literal: true

require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "draft invoice has no number until sent" do
    account = accounts(:one)
    client = clients(:one)
    invoice = account.invoices.create!(
      client: client,
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_nil invoice.invoice_number
  end

  test "computes subtotal, vat_total and total from line items" do
    invoice = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current, due_on: Date.current + 30)
    invoice.line_items.create!(description: "A", quantity: 2, unit_code: "C62", unit_price_cents: 10_000, tax_category_code: "S", vat_rate: 21)
    invoice.line_items.create!(description: "B", quantity: 1, unit_code: "C62", unit_price_cents: 5_000, tax_category_code: "S", vat_rate: 21)

    assert_equal 25_000, invoice.subtotal
    assert_equal 5_250, invoice.vat_total
    assert_equal 30_250, invoice.total
  end

  test "rounds VAT once per category, not per line" do
    invoice = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current, due_on: Date.current + 30)
    3.times do
      invoice.line_items.create!(description: "1c line", quantity: 1, unit_code: "C62", unit_price_cents: 1, tax_category_code: "S", vat_rate: 21)
    end

    # Per-line VAT would be round(1 * 0.21) = 0 three times = 0; EN 16931 rounds
    # the category total once: round(3 * 0.21) = 1.
    assert_equal 3, invoice.subtotal
    assert_equal 1, invoice.vat_total
    assert_equal 4, invoice.total
  end

  test "breaks down VAT by category and rate, mapping reduced rates to S" do
    invoice = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current, due_on: Date.current + 30)
    invoice.line_items.create!(description: "Standard", quantity: 1, unit_code: "C62", unit_price_cents: 10_000, tax_category_code: "S", vat_rate: 21)
    invoice.line_items.create!(description: "Reduced", quantity: 1, unit_code: "C62", unit_price_cents: 10_000, tax_category_code: "S12", vat_rate: 12)

    breakdown = invoice.vat_breakdown

    assert_equal 2, breakdown.size
    assert_equal %w[S S], breakdown.keys.map(&:first)
    assert_equal [ 10_000, 10_000 ], breakdown.values.map { |g| g[:taxable_cents] }
    assert_equal [ 2100, 1200 ], breakdown.values.map { |g| g[:vat_cents] }
    assert_equal 20_000, invoice.subtotal
    assert_equal 3300, invoice.vat_total
    assert_equal 23_300, invoice.total
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

  test "rejects a client belonging to another account" do
    invoice = accounts(:one).invoices.build(
      client: clients(:two),
      issued_on: Date.current,
      due_on: Date.current + 30
    )

    assert_not invoice.valid?
    assert_includes invoice.errors[:client], "must belong to your account"
  end

  test "overdue? is true for sent invoices past their due date" do
    invoice = accounts(:one).invoices.create!(
      client: clients(:one),
      issued_on: Date.current - 30,
      due_on: Date.current - 1,
      status: :sent,
      invoice_number: "INV-0001"
    )

    assert invoice.overdue?
    assert_equal "overdue", invoice.display_status
  end

  test "overdue? is false for sent invoices not yet due" do
    invoice = accounts(:one).invoices.create!(
      client: clients(:one),
      issued_on: Date.current,
      due_on: Date.current + 30,
      status: :sent,
      invoice_number: "INV-0002"
    )

    assert_not invoice.overdue?
    assert_equal "sent", invoice.display_status
  end

  test "overdue? is false for draft and paid invoices regardless of due date" do
    draft = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current - 30, due_on: Date.current - 1, status: :draft)
    paid = accounts(:one).invoices.create!(client: clients(:one), issued_on: Date.current - 30, due_on: Date.current - 1, status: :paid, invoice_number: "INV-0003")

    assert_not draft.overdue?
    assert_not paid.overdue?
    assert_equal "draft", draft.display_status
    assert_equal "paid", paid.display_status
  end

  test "overdue scope includes sent past-due invoices only" do
    sent_overdue = accounts(:one).invoices.create!(
      client: clients(:one), issued_on: Date.current - 30, due_on: Date.current - 1,
      status: :sent, invoice_number: "INV-0100"
    )
    accounts(:one).invoices.create!(
      client: clients(:one), issued_on: Date.current - 30, due_on: Date.current - 1
    ) # past-due draft must be excluded
    accounts(:one).invoices.create!(
      client: clients(:one), issued_on: Date.current, due_on: Date.current + 30,
      status: :sent, invoice_number: "INV-0101"
    ) # sent but not yet due

    assert_equal [ sent_overdue ], accounts(:one).invoices.overdue.to_a
  end
end
