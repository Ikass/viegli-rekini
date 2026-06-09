# frozen_string_literal: true

class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy]

  def index
    # Scope through current_user.account — never query Client directly.
    # This ensures one account can never see another account's clients.
    @clients = Current.user.account.clients
  end

  def show
  end

  def new
    # Build through the association so account_id is set automatically.
    @client = Current.user.account.clients.build
  end

  def create
    @client = Current.user.account.clients.build(client_params)

    if @client.save
      redirect_to @client, notice: "Client created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Client updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
    redirect_to clients_path, notice: "Client deleted."
  end

  private

  def set_client
    # find_by! raises ActiveRecord::RecordNotFound if the client doesn't exist
    # OR doesn't belong to the current account. This prevents one user from
    # accessing another account's clients by guessing IDs in the URL.
    @client = Current.user.account.clients.find_by!(id: params[:id])
  end

  def client_params
    params.expect(client: [ :name, :email, :company_name, :vat_number, :address, :city, :postal_code, :country, :country_code, :is_budget_institution, :delivery_channel, :iban, :e_adrese_id ])
  end
end
