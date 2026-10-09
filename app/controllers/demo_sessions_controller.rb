# frozen_string_literal: true

class DemoSessionsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  # One-click entry to the seeded demo tenant. Find-only — never creates a user
  # or tenant; if the demo account is missing, show a clear error rather than
  # silently fabricating an empty one.
  def create
    user = DemoAccount.user

    if user
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Welcome to the demo!"
    else
      redirect_to new_session_path, alert: "The demo account is not available yet — please try again later."
    end
  end
end
