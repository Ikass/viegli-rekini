# frozen_string_literal: true

require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @client = clients(:one)
    @invoice = @account.invoices.create!(
      client: @client,
      issued_on: Date.current,
      due_on: Date.current + 14
    )
  end

  test "valid line item saves" do
    item = @invoice.line_items.build(
      description: "Test item",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert item.save
  end

  test "requires description" do
    item = @invoice.line_items.build(
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:description], "can't be blank"
  end

  test "requires quantity" do
    item = @invoice.line_items.build(
      description: "Test",
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:quantity], "can't be blank"
  end

  test "quantity must be greater than 0" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 0,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "requires unit_price_cents" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: nil,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:unit_price_cents], "can't be blank"
  end

  test "unit_price_cents must be non-negative" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: -1,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:unit_price_cents], "must be greater than or equal to 0"
  end

  test "requires vat_rate" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: nil
    )
    assert_not item.valid?
    assert_includes item.errors[:vat_rate], "can't be blank"
  end

  test "vat_rate must be non-negative" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: -1
    )
    assert_not item.valid?
    assert_includes item.errors[:vat_rate], "must be greater than or equal to 0"
  end

  test "requires unit_code" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: nil,
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:unit_code], "can't be blank"
  end

  test "requires valid unit_code" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "INVALID",
      unit_price_cents: 1000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:unit_code], "is not included in the list"
  end

  test "requires tax_category_code" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: nil,
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:tax_category_code], "can't be blank"
  end

  test "requires valid tax_category_code" do
    item = @invoice.line_items.build(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 1000,
      tax_category_code: "INVALID",
      vat_rate: 21
    )
    assert_not item.valid?
    assert_includes item.errors[:tax_category_code], "is not included in the list"
  end

  test "unit_price virtual attribute converts from cents" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 5000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_equal "50.00", item.unit_price
  end

  test "unit_price virtual attribute converts to cents" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 5000,
      tax_category_code: "S",
      vat_rate: 21
    )
    item.unit_price = "99.99"
    assert_equal 9999, item.unit_price_cents
  end

  test "subtotal calculates quantity × unit_price_cents" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 3,
      unit_code: "C62",
      unit_price_cents: 5000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_equal 15_000, item.subtotal
  end

  test "subtotal rounds fractional cents half-up" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 1.5,
      unit_code: "C62",
      unit_price_cents: 333,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_equal 500, item.subtotal
  end

  test "vat_amount calculates subtotal × vat_rate / 100" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 10_000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_equal 2100, item.vat_amount
  end

  test "total is subtotal + vat_amount" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 10_000,
      tax_category_code: "S",
      vat_rate: 21
    )
    assert_equal 12_100, item.total
  end

  test "vat_amount is zero when rate is zero" do
    item = @invoice.line_items.create!(
      description: "Test",
      quantity: 1,
      unit_code: "C62",
      unit_price_cents: 10_000,
      tax_category_code: "Z",
      vat_rate: 0
    )
    assert_equal 0, item.vat_amount
    assert_equal 10_000, item.total
  end
end
