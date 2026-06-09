# frozen_string_literal: true

class AccountsController < ApplicationController
  def edit
    @account = Current.user.account
  end

  def update
    @account = Current.user.account

    if @account.update(account_params)
      redirect_to root_path, notice: "Settings updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.expect(account: [ :company_name, :registration_number, :vat_number, :address, :city, :postal_code, :country, :bank_name, :bank_account, :bank_swift, :payment_terms, :invoice_prefix, :invoice_number_padding ])
  end
end
