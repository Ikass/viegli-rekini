# frozen_string_literal: true

require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "default vat_regime is standard" do
    client = Client.new(name: "Test", account: accounts(:one))
    assert_equal "standard", client.vat_regime
  end

  test "vat_regime_note returns nil for standard regime" do
    client = clients(:one)
    client.update_column(:vat_regime, 0)
    assert_nil client.vat_regime_note
  end

  test "vat_regime_note for reverse_charge" do
    client = clients(:one)
    client.update_column(:vat_regime, 1)
    assert_match(/Reverse charge/i, client.vat_regime_note)
  end

  test "vat_regime_note for export" do
    client = clients(:one)
    client.update_column(:vat_regime, 2)
    assert_match(/Export/i, client.vat_regime_note)
  end

  test "check constraint rejects invalid vat_regime" do
    client = clients(:one)
    assert_raises(ActiveRecord::StatementInvalid) do
      client.update_column(:vat_regime, 99)
    end
  end
end
