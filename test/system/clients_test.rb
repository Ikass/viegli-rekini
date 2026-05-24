require "application_system_test_case"

class ClientsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "creating a client" do
    visit new_client_url

    fill_field_via_js("input[name='client[name]']", "Anna Ozola")
    fill_field_via_js("input[name='client[company_name]']", "Ozola SIA")
    fill_field_via_js("input[name='client[email]']", "anna@ozola.lv")
    fill_field_via_js("input[name='client[vat_number]']", "LV88888888888")
    fill_field_via_js("input[name='client[address]']", "Gertrūdes iela 5")
    fill_field_via_js("input[name='client[city]']", "Rīga")
    fill_field_via_js("input[name='client[postal_code]']", "LV-1010")
    fill_field_via_js("input[name='client[country]']", "Latvija")
    submit_via_native_form

    assert_text "Client created"
    assert_text "Anna Ozola"
    assert_text "Ozola SIA"
  end

  test "editing a client" do
    visit edit_client_url(clients(:one))

    fill_field_via_js("input[name='client[name]']", "Updated Name")
    submit_via_native_form

    assert_text "Client updated"
    assert_text "Updated Name"
  end

  test "viewing client details" do
    client = clients(:one)
    visit client_url(client)
    assert_text client.name
  end
end
