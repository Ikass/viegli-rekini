# frozen_string_literal: true

require "application_system_test_case"

class SessionsSystemTest < ApplicationSystemTestCase
  test "signing out returns to the homepage" do
    sign_in_as(users(:one))

    assert_current_path dashboard_path

    click_button I18n.t("layouts.application.sign_out")

    assert_current_path root_path
    assert_text "Rēķins trīs soļos"
  end
end
