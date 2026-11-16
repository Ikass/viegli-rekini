# frozen_string_literal: true

class DemoSessionsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: t("controllers.demo_sessions.rate_limited") }

  # One-click entry to the seeded demo tenant. Find-only — never creates a user
  # or tenant; if the demo account is missing, show a clear error rather than
  # silently fabricating an empty one.
  def create
    user = DemoAccount.user

    if user
      start_new_session_for user
      redirect_to after_authentication_url, notice: t("controllers.demo_sessions.welcome")
    else
      redirect_to new_session_path, alert: t("controllers.demo_sessions.unavailable")
    end
  end
end
