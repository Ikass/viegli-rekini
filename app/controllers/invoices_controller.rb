# frozen_string_literal: true

class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy print pdf]

  def index
    @invoices = Current.user.account.invoices.order(created_at: :desc)
  end

  def show
  end

  def print
    render layout: "print"
  end

  def pdf
    html = render_to_string(template: "invoices/print", layout: "print")
    invoice_pdf = InvoicePdf.new(@invoice)

    send_data invoice_pdf.render(html: html, display_url: request.base_url),
      filename: invoice_pdf.filename,
      type: "application/pdf",
      disposition: :attachment
  end

  def new
    @invoice = Current.user.account.invoices.build(
      issued_on: Date.current,
      due_on: Date.current + 14.days
    )
    # Pre-build one empty line item so the form has a starting row.
    @invoice.line_items.build(position: @invoice.line_items.size)
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
    if @invoice.draft?
      redirect_to @invoice
    else
      redirect_to @invoice, alert: "This invoice is locked and can no longer be edited."
    end
  end

  def update
    unless @invoice.draft?
      redirect_to @invoice, alert: "This invoice is locked and can no longer be edited."
      return
    end

    if @invoice.update(invoice_params)
      if params[:commit] == "send"
        result = InvoiceSender.new.send_invoice(invoice: @invoice)
        if result.success?
          redirect_to @invoice, notice: "Invoice sent."
        else
          flash.now[:alert] = result.error
          render :show, status: :unprocessable_entity
        end
      else
        redirect_to @invoice, notice: "Invoice updated."
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    unless @invoice.draft?
      redirect_to @invoice, alert: "Only draft invoices can be deleted."
      return
    end

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
