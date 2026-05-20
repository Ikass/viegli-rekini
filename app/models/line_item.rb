# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :vat_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Virtual attribute for form-friendly price input (euros, not cents).
  # The getter formats cents as a decimal string for the form.
  # The setter converts the decimal string back to integer cents.
  attribute :unit_price, :string

  def unit_price
    unit_price_cents ? format("%.2f", unit_price_cents / 100.0) : nil
  end

  def unit_price=(value)
    if value.present?
      # Remove commas and convert to float, then to cents.
      # "1 234,56" (Latvian format) → 123456 cents is not handled here;
      # for now we accept standard decimal input: "1234.56"
      self.unit_price_cents = (value.to_s.delete(",").to_f * 100).round
    end
  end

  # Subtotal in cents: quantity × unit price.
  def subtotal
    (quantity * unit_price_cents).to_i
  end

  # VAT amount in cents.
  def vat_amount
    (subtotal * vat_rate / 100).round
  end

  # Line total including VAT.
  def total
    subtotal + vat_amount
  end
end
