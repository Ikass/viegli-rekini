# frozen_string_literal: true

require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
    sign_in_as(@user)
  end

  test "index" do
    get products_path
    assert_response :success
  end

  test "show" do
    get product_path(@product)
    assert_response :success
  end

  test "show rejects a product from another account" do
    get product_path(products(:two))
    assert_response :not_found
  end

  test "new" do
    get new_product_path
    assert_response :success
  end

  test "create" do
    assert_difference("Product.count") do
      post products_path, params: { product: { name: "New Product", default_price: "100.00", default_vat_rate: "21.0", unit_code: "C62", tax_category_code: "S" } }
    end
    assert_redirected_to product_path(Product.last)
  end

  test "edit" do
    get edit_product_path(@product)
    assert_response :success
  end

  test "update" do
    patch product_path(@product), params: { product: { name: "Updated Name" } }
    assert_redirected_to product_path(@product)
    assert_equal "Updated Name", @product.reload.name
  end

  test "destroy" do
    assert_difference("Product.count", -1) do
      delete product_path(@product)
    end
    assert_redirected_to products_path
  end
end
