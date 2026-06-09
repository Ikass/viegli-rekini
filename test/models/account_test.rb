# frozen_string_literal: true

require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "invoice_number_padding must be positive" do
    account = accounts(:one)
    account.invoice_number_padding = 0
    assert_not account.valid?
    assert_includes account.errors[:invoice_number_padding], "must be greater than 0"
  end

  test "invoice_number_padding max is 10" do
    account = accounts(:one)
    account.invoice_number_padding = 11
    assert_not account.valid?
    assert_includes account.errors[:invoice_number_padding], "must be less than or equal to 10"
  end
end
