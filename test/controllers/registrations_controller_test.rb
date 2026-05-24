require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid params" do
    assert_difference([ "Account.count", "User.count" ]) do
      post registration_path, params: { user: { email_address: "new@example.com", password: "password", password_confirmation: "password" } }
    end
    assert_redirected_to root_path
  end

  test "create with invalid params" do
    assert_no_difference([ "Account.count", "User.count" ]) do
      post registration_path, params: { user: { email_address: "", password: "", password_confirmation: "" } }
    end
    assert_response :unprocessable_entity
  end
end
