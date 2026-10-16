# frozen_string_literal: true

require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    sign_in_as(users(:one))
  end

  test "redirects unauthenticated visitors to sign in" do
    sign_out

    get root_path

    assert_redirected_to new_session_path
  end

  test "does not count a past-due draft as overdue" do
    create_invoice(status: :draft, issued_on: Date.current - 30, due_on: Date.current - 1)

    get root_path

    assert_response :success
    assert_select "a.summary-stat--link", false
    assert_select "[data-testid='kpi-overdue']", text: "€0.00"
  end

  test "counts a sent invoice past its due date as overdue (singular)" do
    create_invoice(status: :sent, invoice_number: "INV-0001",
                   issued_on: Date.current - 30, due_on: Date.current - 1)

    get root_path

    assert_response :success
    assert_select ".summary-count", text: /1 overdue invoice/
    assert_select "a.summary-stat--link[href=?]", invoices_path(status: "overdue")
  end

  test "pluralizes overdue text and links to the filtered list" do
    create_invoice(status: :sent, invoice_number: "INV-0001",
                   issued_on: Date.current - 30, due_on: Date.current - 1)
    create_invoice(status: :sent, invoice_number: "INV-0002",
                   issued_on: Date.current - 30, due_on: Date.current - 2)

    get root_path

    assert_response :success
    assert_select ".summary-count", text: /2 overdue invoices/
    assert_select "a.summary-stat--link[href=?]", invoices_path(status: "overdue")
  end

  test "does not count drafts towards outstanding" do
    invoice = create_invoice(status: :draft, issued_on: Date.current, due_on: Date.current + 30)
    add_priced_line_item(invoice)

    get root_path

    assert_select "[data-testid='kpi-outstanding']", text: "€0.00"
  end

  test "counts sent invoices towards outstanding" do
    invoice = create_invoice(status: :sent, invoice_number: "INV-0002",
                             issued_on: Date.current, due_on: Date.current + 30)
    add_priced_line_item(invoice)

    get root_path

    assert_select "[data-testid='kpi-outstanding']", text: "€242.00"
  end

  private

  def create_invoice(status:, issued_on:, due_on:, invoice_number: nil)
    @account.invoices.create!(
      client: clients(:one),
      issued_on: issued_on,
      due_on: due_on,
      status: status,
      invoice_number: invoice_number
    )
  end

  def add_priced_line_item(invoice, unit_price_cents: 20_000)
    invoice.line_items.create!(
      description: "Work", quantity: 1, unit_code: "C62",
      unit_price_cents: unit_price_cents, tax_category_code: "S", vat_rate: 21
    )
  end
end
