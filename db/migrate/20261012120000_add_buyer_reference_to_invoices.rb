class AddBuyerReferenceToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :buyer_reference, :string
  end
end
