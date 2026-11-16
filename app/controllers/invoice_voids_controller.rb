# frozen_string_literal: true

class InvoiceVoidsController < ApplicationController
  def create
    invoice = Current.user.account.invoices.find_by!(id: params[:invoice_id])
    result = InvoiceVoider.new.void_invoice(invoice: invoice)

    if result.success?
      redirect_to invoice_path(invoice), notice: t("controllers.invoice_voids.voided")
    else
      redirect_to invoice_path(invoice), alert: t("controllers.invoice_voids.already_void")
    end
  end
end
