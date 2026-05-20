class AddAccountToUsers < ActiveRecord::Migration[8.1]
  def change
    # null: false is correct here — every user must belong to an account.
    # In development, run db:reset if this fails due to existing rows.
    # In production, this would need a multi-step migration: add nullable,
    # backfill, then add the constraint. We don't have production data yet.
    add_reference :users, :account, null: false, foreign_key: true
  end
end
