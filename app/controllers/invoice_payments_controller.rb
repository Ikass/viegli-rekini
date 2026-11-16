# frozen_string_literal: true

class InvoicePaymentsController < ApplicationController
  def create
    invoice = Current.user.account.invoices.find_by!(id: params[:invoice_id])
    result = InvoicePaymentRecorder.new.record_payment(invoice: invoice)

    if result.success?
      redirect_to invoice_path(invoice), notice: t("controllers.invoice_payments.recorded")
    else
      redirect_to invoice_path(invoice), alert: t("controllers.invoice_payments.only_sent")
    end
  end
end
