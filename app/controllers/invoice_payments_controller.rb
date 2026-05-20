# frozen_string_literal: true

class InvoicePaymentsController < ApplicationController
  def create
    invoice = Current.user.account.invoices.find_by!(id: params[:invoice_id])
    result = InvoicePaymentRecorder.new.record_payment(invoice: invoice)

    if result.success?
      redirect_to invoice_path(invoice), notice: "Payment recorded."
    else
      redirect_to invoice_path(invoice), alert: "Payment can only be recorded for sent invoices."
    end
  end
end
