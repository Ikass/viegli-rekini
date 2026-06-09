class AddEInvoiceFieldsToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :country_code, :string
    add_column :clients, :is_budget_institution, :boolean, null: false, default: false
    add_column :clients, :delivery_channel, :integer, null: false, default: 0
    add_column :clients, :iban, :string
    add_column :clients, :e_adrese_id, :string

    add_check_constraint :clients, "delivery_channel IN (0, 1)", name: "clients_delivery_channel_check"
  end
end
