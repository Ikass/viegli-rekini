# frozen_string_literal: true

class InvoicePdf
  def initialize(invoice)
    @invoice = invoice
  end

  def render(html:, display_url:)
    FerrumPdf.render_pdf(html: html, display_url: display_url)
  end

  def filename
    "#{@invoice.invoice_number}.pdf"
  end
end
