# frozen_string_literal: true

class LineItem < ApplicationRecord
  include InvoiceCodes
  include MoneyRounding

  belongs_to :invoice

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :vat_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_code, presence: true, inclusion: { in: UNIT_CODES.keys }
  validates :tax_category_code, presence: true, inclusion: { in: TAX_CATEGORY_CODES.keys }

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

  # Line net in cents: quantity × unit price, rounded half-up to the nearest
  # cent (EN 16931 rounds line net to two decimals). quantity is decimal, so a
  # fractional quantity × an odd price can produce a fractional cent.
  # Returns 0 for an incomplete (unsaved) line item so form renders don't blow up.
  def subtotal
    return 0 if quantity.nil? || unit_price_cents.nil?

    round_half_up_to_cent(quantity * unit_price_cents)
  end

  # VAT amount in cents, per line. Display-only: the invoice-level VAT is
  # computed once per category (see Invoice#vat_breakdown), not summed from this.
  def vat_amount
    return 0 if vat_rate.nil?

    round_half_up_to_cent(subtotal * vat_rate / 100)
  end

  # Line total including VAT.
  def total
    subtotal + vat_amount
  end
end
