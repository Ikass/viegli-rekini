class AddRegistrationNumberToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :registration_number, :string
  end
end
