require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:one)
    sign_in_as(@user)
  end

  test "index" do
    get invoices_path
    assert_response :success
  end

  test "show" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0001", issued_on: Date.current, due_on: Date.current + 14.days)
    get invoice_path(invoice)
    assert_response :success
    assert_select "a[href=?]", pdf_invoice_path(invoice), text: /Download PDF/
  end

  test "show rejects an invoice belonging to another account" do
    foreign_invoice = accounts(:two).invoices.create!(client: clients(:two), invoice_number: "INV-FOREIGN", issued_on: Date.current, due_on: Date.current + 14.days)

    get invoice_path(foreign_invoice)

    assert_response :not_found
  end

  test "create rejects a client_id belonging to another account" do
    assert_no_difference("Invoice.count") do
      post invoices_path, params: { invoice: {
        client_id: clients(:two).id,
        issued_on: Date.current,
        due_on: Date.current + 14.days
      } }
    end

    assert_response :not_found
  end

  test "new" do
    get new_invoice_path
    assert_response :success
  end

  test "create with valid params" do
    assert_difference([ "Invoice.count", "LineItem.count" ]) do
      post invoices_path, params: { invoice: {
        client_id: @client.id,
        issued_on: Date.current,
        due_on: Date.current + 14.days,
        line_items_attributes: {
          "0" => { description: "Design work", quantity: 10, unit_code: "C62", unit_price: "50.00", tax_category_code: "S", vat_rate: 21 }
        }
      } }
    end
    assert_redirected_to invoice_path(Invoice.last)
  end

  test "create with invalid params" do
    assert_no_difference("Invoice.count") do
      post invoices_path, params: { invoice: { client_id: "", issued_on: "", due_on: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit redirects drafts to show for inline editing" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0002", issued_on: Date.current, due_on: Date.current + 14.days)
    get edit_invoice_path(invoice)
    assert_redirected_to invoice_path(invoice)
  end

  test "edit redirects non-draft invoices to show" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0002b", issued_on: Date.current, due_on: Date.current + 14.days, status: :sent)
    get edit_invoice_path(invoice)
    assert_redirected_to invoice_path(invoice)
    assert_equal "This invoice is locked and can no longer be edited.", flash[:alert]
  end

  test "update" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0003", issued_on: Date.current, due_on: Date.current + 14.days)
    patch invoice_path(invoice), params: { invoice: { notes: "Updated notes" } }
    assert_redirected_to invoice_path(invoice)
    assert_equal "Updated notes", invoice.reload.notes
  end

  test "update rejects non-draft invoices" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0003b", issued_on: Date.current, due_on: Date.current + 14.days, status: :sent)
    patch invoice_path(invoice), params: { invoice: { notes: "Should not save" } }
    assert_redirected_to invoice_path(invoice)
    assert_nil invoice.reload.notes
  end

  test "update rejects a client_id belonging to another account" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0003c", issued_on: Date.current, due_on: Date.current + 14.days)

    assert_no_changes -> { invoice.reload.client_id } do
      patch invoice_path(invoice), params: { invoice: { client_id: clients(:two).id, notes: "Should not save" } }
    end

    assert_response :not_found
  end

  test "update with commit=send saves then sends the invoice" do
    @user.account.update!(
      company_name: "SIA Test",
      registration_number: "LV40001234567",
      address: "Brīvības iela 100",
      city: "Rīga",
      postal_code: "LV-1001",
      country: "Latvija",
      bank_name: "Swedbank",
      bank_account: "LV12HABA0001234567890"
    )
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-SEND1", issued_on: Date.current, due_on: Date.current + 14.days)
    invoice.line_items.create!(description: "Work", quantity: 1, unit_code: "C62", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21)

    patch invoice_path(invoice), params: { invoice: { notes: "Saved before send" }, commit: "send" }

    assert_redirected_to invoice_path(invoice)
    assert invoice.reload.sent?
    assert_equal "Saved before send", invoice.notes
  end

  test "update with commit=send surfaces the send error when legal fields are missing" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-SEND2", issued_on: Date.current, due_on: Date.current + 14.days)
    invoice.line_items.create!(description: "Work", quantity: 1, unit_code: "C62", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21)

    patch invoice_path(invoice), params: { invoice: { notes: "Still saved" }, commit: "send" }

    assert_response :unprocessable_entity
    assert invoice.reload.draft?
    assert_equal "Still saved", invoice.notes
    assert_includes response.body, "Cannot send invoice"
  end

  test "destroy" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0004", issued_on: Date.current, due_on: Date.current + 14.days)
    assert_difference("Invoice.count", -1) do
      delete invoice_path(invoice)
    end
    assert_redirected_to invoices_path
  end

  test "destroy rejects non-draft invoices" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0004b", issued_on: Date.current, due_on: Date.current + 14.days, status: :sent)
    assert_no_difference("Invoice.count") do
      delete invoice_path(invoice)
    end
    assert_redirected_to invoice_path(invoice)
  end

  test "print renders the shared document" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0005", issued_on: Date.current, due_on: Date.current + 14.days)
    invoice.line_items.create!(description: "Consulting", quantity: 1, unit_code: "C62", unit_price_cents: 10_000, tax_category_code: "S", vat_rate: 21, position: 0)

    get print_invoice_path(invoice)
    assert_response :success
    assert_match "INV-0005", response.body
    assert_match "Consulting", response.body
    assert_match 'charset="utf-8"', response.body
  end

  test "print does not leak literal template syntax or the PEPPOL note" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0006", issued_on: Date.current, due_on: Date.current + 14.days)
    get print_invoice_path(invoice)
    assert_no_match(/<#/, response.body)
    assert_no_match(/PEPPOL-ready/, response.body)
  end

  test "pdf renders a downloadable invoice PDF" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0007", issued_on: Date.current, due_on: Date.current + 14.days)

    fake_pdf = "%PDF-1.4\nfake content".b
    FerrumPdf.define_singleton_method(:render_pdf) { |**| fake_pdf }

    get pdf_invoice_path(invoice)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "INV-0007.pdf", response.headers["Content-Disposition"]
    assert_equal fake_pdf, response.body
  ensure
    FerrumPdf.singleton_class.remove_method(:render_pdf)
  end
end
