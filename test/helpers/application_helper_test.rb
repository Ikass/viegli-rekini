# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "strips trailing zero for whole-number rates" do
    assert_equal "21%", vat_rate_percentage(BigDecimal("21.0"))
    assert_equal "0%", vat_rate_percentage(BigDecimal("0.0"))
  end

  test "preserves fractional rates" do
    assert_equal "5.5%", vat_rate_percentage(BigDecimal("5.5"))
  end

  test "handles plain integers" do
    assert_equal "21%", vat_rate_percentage(21)
  end
end
