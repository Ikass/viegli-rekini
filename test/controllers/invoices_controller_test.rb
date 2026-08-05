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

  test "edit" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0002", issued_on: Date.current, due_on: Date.current + 14.days)
    get edit_invoice_path(invoice)
    assert_response :success
  end

  test "update" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0003", issued_on: Date.current, due_on: Date.current + 14.days)
    patch invoice_path(invoice), params: { invoice: { notes: "Updated notes" } }
    assert_redirected_to invoice_path(invoice)
    assert_equal "Updated notes", invoice.reload.notes
  end

  test "destroy" do
    invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0004", issued_on: Date.current, due_on: Date.current + 14.days)
    assert_difference("Invoice.count", -1) do
      delete invoice_path(invoice)
    end
    assert_redirected_to invoices_path
  end
end
