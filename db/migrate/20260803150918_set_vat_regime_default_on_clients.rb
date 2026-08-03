# frozen_string_literal: true

class SetVatRegimeDefaultOnClients < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        Client.where(vat_regime: nil).update_all(vat_regime: 0)
        change_column_default :clients, :vat_regime, from: nil, to: 0
      end
      dir.down do
        change_column_default :clients, :vat_regime, from: 0, to: nil
      end
    end
  end
end
