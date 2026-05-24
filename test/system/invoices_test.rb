require "application_system_test_case"

class InvoicesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @account = @user.account
    sign_in_as(@user)
  end

  test "full invoice lifecycle" do
    # --- Create a client ---
    visit new_client_url
    fill_field_via_js("input[name='client[name]']", "System Test Client")
    fill_field_via_js("input[name='client[company_name]']", "STC Ltd")
    fill_field_via_js("input[name='client[email]']", "client@test.lv")
    fill_field_via_js("input[name='client[vat_number]']", "LV99999999999")
    fill_field_via_js("input[name='client[address]']", "Testa iela 1")
    fill_field_via_js("input[name='client[city]']", "Rīga")
    fill_field_via_js("input[name='client[postal_code]']", "LV-1001")
    fill_field_via_js("input[name='client[country]']", "Latvija")
    submit_via_native_form
    assert_text "Client created"
    assert_text "System Test Client"

    # --- Create a product ---
    visit new_product_url
    fill_field_via_js("input[name='product[name]']", "Testpakalpojums")
    fill_field_via_js("input[name='product[default_price]']", "150.00")
    fill_field_via_js("input[name='product[default_vat_rate]']", "21")
    fill_field_via_js("textarea[name='product[description]']", "Testa pakalpojums sistēmu testēšanai")
    submit_via_native_form
    assert_text "Product created"

    # --- Create an invoice ---
    visit new_invoice_url
    select "System Test Client", from: "invoice_client_id"
    fill_field_via_js("input[name='invoice[issued_on]']", Date.current.to_s)
    fill_field_via_js("input[name='invoice[due_on]']", (Date.current + 14.days).to_s)

    # Add a line item via product picker
    within first("[data-controller='product-picker']") do
      select "Testpakalpojums", from: "product_selector"
    end

    # Wait for product picker AJAX to fill fields
    sleep 0.5

    submit_via_native_form
    assert_text "Invoice created"
    assert_text "INV-"
    assert_text "System Test Client"
    assert_text "€181.50"

    # --- Send the invoice ---
    page.execute_script("document.querySelector('form.button_to[action*=\"invoice_sends\"]')?.submit()")
    assert_text "SENT"
    assert_text "Record payment"

    # --- Record payment ---
    page.execute_script("document.querySelector('form.button_to[action*=\"invoice_payments\"]')?.submit()")
    assert_text "PAID"

    # --- Visit print view ---
    click_link "Print"
    assert_text "INV-"
    assert_text "System Test Client"
    assert_text "Testa pakalpojums sistēmu testēšanai"

    # --- Go back and void a different invoice ---
    visit new_invoice_url
    select "System Test Client", from: "invoice_client_id"
    fill_field_via_js("input[name='invoice[issued_on]']", Date.current.to_s)
    fill_field_via_js("input[name='invoice[due_on]']", (Date.current + 14.days).to_s)

    within first("[data-controller='product-picker']") do
      select "Testpakalpojums", from: "product_selector"
    end

    sleep 0.5

    submit_via_native_form
    assert_text "Invoice created"

    page.execute_script("document.querySelector('form.button_to[action*=\"invoice_voids\"]')?.submit()")
    assert_text "VOID"
  end
end
