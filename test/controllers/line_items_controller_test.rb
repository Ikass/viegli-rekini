require "test_helper"

class LineItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:one)
    sign_in_as(@user)
    @invoice = @user.account.invoices.create!(client: @client, invoice_number: "INV-0001", issued_on: Date.current, due_on: Date.current + 14.days)
  end

  test "new" do
    get new_invoice_line_item_path(@invoice)
    assert_response :success
  end

  test "create with valid params" do
    assert_difference("LineItem.count") do
      post invoice_line_items_path(@invoice), params: { line_item: {
        description: "Consulting", quantity: 5, unit_code: "HUR", unit_price: "100.00", tax_category_code: "S", vat_rate: 21
      } }
    end
    assert_redirected_to invoice_path(@invoice)
  end

  test "create with invalid params" do
    assert_no_difference("LineItem.count") do
      post invoice_line_items_path(@invoice), params: { line_item: { description: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit rejects a line item from another account" do
    foreign_invoice = accounts(:two).invoices.create!(client: clients(:two), invoice_number: "INV-FOREIGN-LI", issued_on: Date.current, due_on: Date.current + 14.days)
    foreign_line_item = foreign_invoice.line_items.create!(description: "Foreign", quantity: 1, unit_code: "C62", unit_price_cents: 1000, tax_category_code: "S", vat_rate: 21)

    get edit_line_item_path(foreign_line_item)

    assert_response :not_found
  end

  test "edit" do
    line_item = @invoice.line_items.create!(description: "Work", quantity: 1, unit_code: "C62", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21)
    get edit_line_item_path(line_item)
    assert_response :success
  end

  test "update" do
    line_item = @invoice.line_items.create!(description: "Work", quantity: 1, unit_code: "C62", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21)
    patch line_item_path(line_item), params: { line_item: { description: "Updated work" } }
    assert_redirected_to invoice_path(@invoice)
    assert_equal "Updated work", line_item.reload.description
  end

  test "destroy" do
    line_item = @invoice.line_items.create!(description: "Work", quantity: 1, unit_code: "C62", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21)
    assert_difference("LineItem.count", -1) do
      delete line_item_path(line_item)
    end
    assert_redirected_to invoice_path(@invoice)
  end

  test "edit rejects non-draft invoices" do
    @invoice.update!(status: :sent)
    line_item = @invoice.line_items.create!(description: "Work", quantity: 1, unit_code: "C62", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21)

    get edit_line_item_path(line_item)
    assert_redirected_to invoice_path(@invoice)
    assert_equal "Line items can only be edited on draft invoices.", flash[:alert]
  end

  test "create rejects non-draft invoices" do
    @invoice.update!(status: :sent)

    assert_no_difference("LineItem.count") do
      post invoice_line_items_path(@invoice), params: { line_item: { description: "Late add", quantity: 1, unit_code: "C62", unit_price: "10.00", tax_category_code: "S", vat_rate: 21 } }
    end
    assert_redirected_to invoice_path(@invoice)
  end
end
