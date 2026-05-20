# frozen_string_literal: true

class RegistrationsController < ApplicationController
  # Registration must be accessible without being logged in —
  # otherwise new users could never sign up.
  allow_unauthenticated_access only: %i[new create]

  def new
    # We instantiate a blank User here so the form has an object to bind to.
    # This is the Rails convention — @user in the view, not a bare form.
    @user = User.new
  end

  def create
    # wrap_params means Rails namespaces form params under "user" automatically.
    # So params[:user][:email_address] etc. We permit only what we expect.
    @user = User.new(registration_params)

    # Build the account first, then assign it to the user.
    # We use a transaction so that if either the account or user fails to save,
    # neither is persisted. Financial apps should be especially careful about
    # partial writes — an account without a user, or a user without an account,
    # would be a data integrity problem.
    ActiveRecord::Base.transaction do
      account = Account.create!(name: default_account_name)
      @user.account = account
      @user.save!
    end

    start_new_session_for @user
    redirect_to root_path, notice: "Welcome! Your account has been created."

  rescue ActiveRecord::RecordInvalid
    # If either save! raises (invalid record), we land here.
    # @user will have the validation errors on it for the form to display.
    render :new, status: :unprocessable_entity
  end

  private

  def registration_params
    params.expect(user: [:email_address, :password, :password_confirmation])
  end

  def default_account_name
    # Derive a reasonable account name from the email address.
    # "reinis@example.com" → "reinis". Can be changed later.
    @user.email_address.to_s.split("@").first.presence || "My Account"
  end
end
