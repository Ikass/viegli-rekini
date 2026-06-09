# frozen_string_literal: true

class InvoiceSendsController < ApplicationController
  def create
    invoice = Current.user.account.invoices.find_by!(id: params[:invoice_id])
    result = InvoiceSender.new.send_invoice(invoice: invoice)

    if result.success?
      redirect_to invoice_path(invoice), notice: "Invoice sent."
    else
      redirect_to invoice_path(invoice), alert: result.error
    end
  end
end
