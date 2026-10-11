# frozen_string_literal: true

require "test_helper"

class InvoiceSequenceTest < ActiveSupport::TestCase
  test "allocates sequential formatted numbers for an account" do
    account = accounts(:one)

    assert_equal "INV-0001", InvoiceSequence.next_for!(account)
    assert_equal "INV-0002", InvoiceSequence.next_for!(account)
  end

  test "sequences are independent per account" do
    assert_equal "INV-0001", InvoiceSequence.next_for!(accounts(:one))
    assert_equal "INV-0001", InvoiceSequence.next_for!(accounts(:two))
  end

  test "sequences are independent per scope" do
    account = accounts(:one)

    assert_equal "INV-0001", InvoiceSequence.next_for!(account, "default")
    assert_equal "INV-0001", InvoiceSequence.next_for!(account, "ecommerce")
  end

  test "formats using the account prefix and padding" do
    account = accounts(:one)
    account.update!(invoice_prefix: "R", invoice_number_padding: 5)

    assert_equal "R-00001", InvoiceSequence.next_for!(account)
  end

  test "handles a digit-bearing prefix without misparsing" do
    account = accounts(:one)
    account.update!(invoice_prefix: "INV2026")

    assert_equal "INV2026-0001", InvoiceSequence.next_for!(account)
    assert_equal "INV2026-0002", InvoiceSequence.next_for!(account)
  end
end
