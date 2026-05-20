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

  test "edit" do
    get edit_client_path(@client)
    assert_response :success
  end

  test "update" do
    patch client_path(@client), params: { client: { name: "Updated Name" } }
    assert_redirected_to client_path(@client)
    assert_equal "Updated Name", @client.reload.name
  end

  test "destroy" do
    assert_difference("Client.count", -1) do
      delete client_path(@client)
    end
    assert_redirected_to clients_path
  end
end
