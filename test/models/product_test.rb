# frozen_string_literal: true

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "valid product saves" do
    product = accounts(:one).products.build(
      name: "Test Product",
      default_price_cents: 1000,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert product.save
  end

  test "requires name" do
    product = accounts(:one).products.build(
      default_price_cents: 1000,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "requires default_price_cents" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: nil,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:default_price_cents], "can't be blank"
  end

  test "requires non-negative default_price_cents" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: -1,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:default_price_cents], "must be greater than or equal to 0"
  end

  test "requires integer default_price_cents" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 10.5,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:default_price_cents], "must be an integer"
  end

  test "requires default_vat_rate" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 1000,
      default_vat_rate: nil,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:default_vat_rate], "can't be blank"
  end

  test "requires non-negative default_vat_rate" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 1000,
      default_vat_rate: -1,
      unit_code: "C62",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:default_vat_rate], "must be greater than or equal to 0"
  end

  test "requires unit_code" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 1000,
      default_vat_rate: 21.0,
      unit_code: nil,
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:unit_code], "can't be blank"
  end

  test "requires valid unit_code" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 1000,
      default_vat_rate: 21.0,
      unit_code: "INVALID",
      tax_category_code: "S"
    )
    assert_not product.valid?
    assert_includes product.errors[:unit_code], "is not included in the list"
  end

  test "allows all valid unit codes" do
    InvoiceCodes::UNIT_CODES.keys.each do |code|
      product = accounts(:one).products.build(
        name: "Test #{code}",
        default_price_cents: 1000,
        default_vat_rate: 21.0,
        unit_code: code,
        tax_category_code: "S"
      )
      assert product.valid?, "Expected #{code} to be valid"
    end
  end

  test "requires tax_category_code" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 1000,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: nil
    )
    assert_not product.valid?
    assert_includes product.errors[:tax_category_code], "can't be blank"
  end

  test "requires valid tax_category_code" do
    product = accounts(:one).products.build(
      name: "Test",
      default_price_cents: 1000,
      default_vat_rate: 21.0,
      unit_code: "C62",
      tax_category_code: "INVALID"
    )
    assert_not product.valid?
    assert_includes product.errors[:tax_category_code], "is not included in the list"
  end

  test "allows all valid tax category codes" do
    InvoiceCodes::TAX_CATEGORY_CODES.keys.each do |code|
      product = accounts(:one).products.build(
        name: "Test #{code}",
        default_price_cents: 1000,
        default_vat_rate: 21.0,
        unit_code: "C62",
        tax_category_code: code
      )
      assert product.valid?, "Expected #{code} to be valid"
    end
  end

  test "default_price virtual attribute converts from cents" do
    product = products(:one)
    product.update_column(:default_price_cents, 15000)
    assert_equal "150.00", product.default_price
  end

  test "default_price virtual attribute converts to cents" do
    product = products(:one)
    product.default_price = "99.99"
    assert_equal 9999, product.default_price_cents
  end
end
