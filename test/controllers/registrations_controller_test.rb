require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new redirects to sign in (sign-up disabled)" do
    get new_registration_path
    assert_redirected_to new_session_path
  end

  test "create redirects and does not create an account (sign-up disabled)" do
    assert_no_difference([ "Account.count", "User.count" ]) do
      post registration_path, params: { user: { email_address: "new@example.com", password: "password", password_confirmation: "password" } }
    end
    assert_redirected_to new_session_path
  end
end
