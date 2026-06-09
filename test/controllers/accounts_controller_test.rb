# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "edit" do
    get edit_account_path
    assert_response :success
  end

  test "update" do
    patch account_path, params: { account: { company_name: "ACME Inc." } }
    assert_redirected_to root_path
    assert_equal "ACME Inc.", @user.account.reload.company_name
  end

  test "update with seller profile fields" do
    patch account_path, params: { account: { invoice_prefix: "R", payment_terms: "30 days net", invoice_number_padding: 5 } }
    assert_redirected_to root_path
    @user.account.reload.tap do |account|
      assert_equal "R", account.invoice_prefix
      assert_equal "30 days net", account.payment_terms
      assert_equal 5, account.invoice_number_padding
    end
  end
end
