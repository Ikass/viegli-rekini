class AddAddressToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :address, :string
    add_column :clients, :city, :string
    add_column :clients, :postal_code, :string
    add_column :clients, :country, :string, default: "Latvia"
  end
end
