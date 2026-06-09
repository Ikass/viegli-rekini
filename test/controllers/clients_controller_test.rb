require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:one)
    sign_in_as(@user)
  end

  test "index" do
    get clients_path
    assert_response :success
  end

  test "show" do
    get client_path(@client)
    assert_response :success
  end

  test "new" do
    get new_client_path
    assert_response :success
  end

  test "create" do
    assert_difference("Client.count") do
      post clients_path, params: { client: { name: "New Client", email: "new@example.com" } }
    end
    assert_redirected_to client_path(Client.last)
  end

  test "create with e-invoice fields" do
    assert_difference("Client.count") do
      post clients_path, params: {
        client: {
          name: "E-Client",
          country_code: "LV",
          is_budget_institution: "1",
          delivery_channel: "e_adrese",
          iban: "LV12HABA0001234567890",
          e_adrese_id: "90000000001"
        }
      }
    end
    assert_response :redirect
    client = Client.find_by!(name: "E-Client")
    assert_equal "LV", client.country_code
    assert client.is_budget_institution?
    assert client.e_adrese?
    assert_equal "LV12HABA0001234567890", client.iban
    assert_equal "90000000001", client.e_adrese_id
  end

  test "edit" do
    get edit_client_path(@client)
    assert_response :success
  end

  test "update" do
    patch client_path(@client), params: { client: { name: "Updated Name" } }
    assert_redirected_to client_path(@client)
    assert_equal "Updated Name", @client.reload.name
  end

  test "update e-invoice fields" do
    patch client_path(@client), params: {
      client: {
        country_code: "EE",
        is_budget_institution: "1",
        delivery_channel: "e_adrese",
        iban: "EE1234567890",
        e_adrese_id: "90000000002"
      }
    }
    assert_redirected_to client_path(@client)
    @client.reload.tap do |c|
      assert_equal "EE", c.country_code
      assert c.is_budget_institution?
      assert c.e_adrese?
      assert_equal "EE1234567890", c.iban
      assert_equal "90000000002", c.e_adrese_id
    end
  end

  test "destroy" do
    assert_difference("Client.count", -1) do
      delete client_path(@client)
    end
    assert_redirected_to clients_path
  end
end
