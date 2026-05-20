# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :account, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true

      t.string :invoice_number, null: false
      t.date :issued_on, null: false
      t.date :due_on, null: false
      t.integer :status, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    # Invoice numbers must be unique per account — two tenants can both have INV-0001,
    # but one tenant cannot have duplicates.
    add_index :invoices, [:account_id, :invoice_number], unique: true

    # Database-level guard so status is always a known enum value, even if
    # Rails validations are bypassed (e.g. update_column).
    add_check_constraint :invoices, "status IN (0, 1, 2, 3)", name: "invoices_status_check"
  end
end
