# frozen_string_literal: true

class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy]

  def index
    @invoices = Current.user.account.invoices.order(created_at: :desc)
  end

  def show
  end

  def new
    @invoice = Current.user.account.invoices.build(
      issued_on: Date.current,
      due_on: Date.current + 14.days
    )
    # Pre-build three empty line items so the form has something to render.
    3.times { @invoice.line_items.build(position: @invoice.line_items.size) }
  end

  def create
    @invoice = Current.user.account.invoices.build(invoice_params)

    if @invoice.save
      redirect_to @invoice, notice: "Invoice created."
    else
      # Ensure there are always line item fields to render, even after a validation failure.
      @invoice.line_items.build(position: @invoice.line_items.size) if @invoice.line_items.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Invoice updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to invoices_path, notice: "Invoice deleted."
  end

  private

  def set_invoice
    @invoice = Current.user.account.invoices.find_by!(id: params[:id])
  end

  def invoice_params
    # Use an empty hash {} for line_items_attributes because Rails 8.1's
    # params.expect does not yet support the nested-hash-with-string-keys
    # syntax that permit handles. This permits any index key ("0", "1", etc.)
    # and any sub-key within each nested item.
    params.expect(invoice: [
      :client_id, :issued_on, :due_on, :notes,
      line_items_attributes: {}
    ])
  end
end
