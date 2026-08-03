class AddVatRegimeToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :vat_regime, :integer
  end
end
