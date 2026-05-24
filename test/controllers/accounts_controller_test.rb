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
end
