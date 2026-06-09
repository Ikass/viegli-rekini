class AddInvoiceNumberPaddingToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :invoice_number_padding, :integer, null: false, default: 4
  end
end
