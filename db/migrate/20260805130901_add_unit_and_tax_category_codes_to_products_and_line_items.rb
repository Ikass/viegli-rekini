# frozen_string_literal: true

class AddUnitAndTaxCategoryCodesToProductsAndLineItems < ActiveRecord::Migration[8.1]
  def change
    change_table :products do |t|
      t.string :unit_code, null: false, default: "C62"
      t.string :tax_category_code, null: false, default: "S"
    end

    change_table :line_items do |t|
      t.string :unit_code, null: false, default: "C62"
      t.string :tax_category_code, null: false, default: "S"
    end
  end
end
