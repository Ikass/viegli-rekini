class AddTransitionTimestampsToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :sent_at, :datetime
    add_column :invoices, :paid_at, :datetime
    add_column :invoices, :voided_at, :datetime
  end
end
