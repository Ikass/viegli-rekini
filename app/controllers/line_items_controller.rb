# frozen_string_literal: true

class LineItemsController < ApplicationController
  before_action :set_invoice, only: %i[new create]
  before_action :set_line_item, only: %i[edit update destroy]
  before_action :ensure_editable_invoice, only: %i[new create edit update destroy]

  def new
    @line_item = @invoice.line_items.build(position: @invoice.line_items.size)
  end

  def create
    @line_item = @invoice.line_items.build(line_item_params)

    if @line_item.save
      redirect_to invoice_path(@invoice), notice: "Line item added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @line_item.update(line_item_params)
      redirect_to invoice_path(@line_item.invoice), notice: "Line item updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    invoice = @line_item.invoice
    @line_item.destroy
    redirect_to invoice_path(invoice), notice: "Line item removed."
  end

  private

  def ensure_editable_invoice
    invoice = @line_item ? @line_item.invoice : @invoice
    return if invoice.draft?

    redirect_to invoice, alert: "Line items can only be edited on draft invoices."
  end

  def set_invoice
    @invoice = Current.user.account.invoices.find_by!(id: params[:invoice_id])
  end

  def set_line_item
    # Shallow routes — no :invoice_id param. Scope through account to prevent
    # one tenant from editing another's line items.
    @line_item = LineItem.joins(:invoice)
      .where(invoices: { account_id: Current.user.account.id })
      .find_by!(id: params[:id])
  end

  def line_item_params
    params.expect(line_item: [ :description, :quantity, :unit_code, :unit_price, :tax_category_code, :vat_rate, :position ])
  end
end
