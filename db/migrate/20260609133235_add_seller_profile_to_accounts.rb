class AddSellerProfileToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :payment_terms, :text
    add_column :accounts, :invoice_prefix, :string, null: false, default: "INV"
  end
end
