require "test_helper"

class DemoSessionsControllerTest < ActionDispatch::IntegrationTest
  test "create signs in the seeded demo user" do
    user = accounts(:one).users.create!(email_address: DemoAccount::EMAIL, password: "password")

    post demo_session_path

    assert_redirected_to root_path
    assert_equal 1, user.sessions.count
  end

  test "create redirects with an alert when the demo user is missing" do
    post demo_session_path

    assert_redirected_to new_session_path
    assert_equal "The demo account is not available yet — please try again later.", flash[:alert]
  end
end
