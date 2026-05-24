class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :default_price_cents, null: false, default: 0
      t.decimal :default_vat_rate, null: false, precision: 5, scale: 2, default: 21.0

      t.timestamps
    end
  end
end
