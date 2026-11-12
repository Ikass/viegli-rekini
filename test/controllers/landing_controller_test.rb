# frozen_string_literal: true

require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  test "redirects / to the English page" do
    get "/"

    assert_redirected_to root_path(locale: :en)
  end

  test "redirects authenticated visitors to the dashboard" do
    sign_in_as(users(:one))

    get "/"

    assert_redirected_to dashboard_path
  end

  test "renders the English landing page" do
    get root_path(locale: :en)

    assert_response :success
    assert_select "h1", text: /Invoices in three steps/
  end

  test "sets the locale from the URL" do
    get "/en"

    assert_response :success
    assert_select "html[lang=en]"
  end

  test "does not require authentication" do
    get "/en"

    assert_response :success
  end
end
