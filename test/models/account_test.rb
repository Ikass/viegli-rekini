# frozen_string_literal: true

require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "invoice_number_padding must be positive" do
    account = accounts(:one)
    account.invoice_number_padding = 0
    assert_not account.valid?
    assert_includes account.errors[:invoice_number_padding], I18n.t("errors.messages.greater_than", count: 0)
  end

  test "invoice_number_padding max is 10" do
    account = accounts(:one)
    account.invoice_number_padding = 11
    assert_not account.valid?
    assert_includes account.errors[:invoice_number_padding], I18n.t("errors.messages.less_than_or_equal_to", count: 10)
  end
end
