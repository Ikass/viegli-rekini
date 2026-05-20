# frozen_string_literal: true

class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :invoice, null: false, foreign_key: true

      t.string :description, null: false
      t.decimal :quantity, null: false, precision: 10, scale: 2
      t.integer :unit_price_cents, null: false
      t.decimal :vat_rate, null: false, default: 0, precision: 5, scale: 2
      t.integer :position

      t.timestamps
    end
  end
end
