# frozen_string_literal: true

class AddVatRegimeCheckConstraintToClients < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :clients, "vat_regime IN (0, 1, 2)", name: "clients_vat_regime_check"
  end
end
