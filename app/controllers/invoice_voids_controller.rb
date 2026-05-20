# frozen_string_literal: true

class InvoiceVoidsController < ApplicationController
  def create
    invoice = Current.user.account.invoices.find_by!(id: params[:invoice_id])
    result = InvoiceVoider.new.void_invoice(invoice: invoice)

    if result.success?
      redirect_to invoice_path(invoice), notice: "Invoice voided."
    else
      redirect_to invoice_path(invoice), alert: "Invoice is already void."
    end
  end
end
