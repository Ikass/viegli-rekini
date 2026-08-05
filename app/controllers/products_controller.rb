# frozen_string_literal: true

class ProductsController < ApplicationController
  before_action :set_product, only: %i[show edit update destroy]

  def index
    @products = Current.user.account.products
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          name: @product.name,
          description: @product.description,
          default_price: @product.default_price,
          default_price_cents: @product.default_price_cents,
          default_vat_rate: @product.default_vat_rate,
          unit_code: @product.unit_code,
          tax_category_code: @product.tax_category_code
        }
      end
    end
  end

  def new
    @product = Current.user.account.products.build
  end

  def create
    @product = Current.user.account.products.build(product_params)

    if @product.save
      redirect_to @product, notice: "Product created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: "Product deleted."
  end

  private

  def set_product
    @product = Current.user.account.products.find_by!(id: params[:id])
  end

  def product_params
    params.expect(product: [ :name, :description, :default_price, :default_vat_rate, :unit_code, :tax_category_code ])
  end
end
