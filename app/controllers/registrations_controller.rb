# frozen_string_literal: true

class RegistrationsController < ApplicationController
  layout "auth"
  # Public sign-up is disabled for the demo — the "Try the demo" button
  # (demo_session_path) is the only entry point. Revert this controller to the
  # original sign-up flow (see git history) when v1 reopens registration.
  allow_unauthenticated_access only: %i[new create]

  def new
    redirect_to new_session_path, notice: "Sign-up is disabled for this demo."
  end

  def create
    redirect_to new_session_path, notice: "Sign-up is disabled for this demo."
  end
end
