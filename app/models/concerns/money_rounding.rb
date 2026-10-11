# frozen_string_literal: true

module MoneyRounding
  extend ActiveSupport::Concern

  # Round a BigDecimal (already in integer cents) half-up to the nearest cent.
  # BigDecimal#round defaults to half-up (0.5 -> 1, 1.5 -> 2, 2.5 -> 3), so this
  # matches EN 16931 / PEPPOL rounding exactly.
  def round_half_up_to_cent(value)
    BigDecimal(value.to_s).round(0).to_i
  end
end
