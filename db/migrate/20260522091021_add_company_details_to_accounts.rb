class AddCompanyDetailsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :company_name, :string
    add_column :accounts, :registration_number, :string
    add_column :accounts, :vat_number, :string
    add_column :accounts, :address, :string
    add_column :accounts, :city, :string
    add_column :accounts, :postal_code, :string
    add_column :accounts, :country, :string, default: "Latvia"
    add_column :accounts, :bank_name, :string
    add_column :accounts, :bank_account, :string
    add_column :accounts, :bank_swift, :string
  end
end
