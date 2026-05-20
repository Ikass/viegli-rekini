class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :account, null: false, foreign_key: true

      # name is the only required field — a client must have a name.
      # email, company_name, vat_number are optional — not all clients
      # are VAT-registered businesses, and we may not always have their email.
      t.string :name, null: false
      t.string :email
      t.string :company_name
      t.string :vat_number

      t.timestamps
    end
  end
end
