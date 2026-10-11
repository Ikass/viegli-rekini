class CreateInvoiceSequences < ActiveRecord::Migration[8.1]
  def up
    create_table :invoice_sequences do |t|
      t.references :account, null: false, foreign_key: true
      t.string :scope, null: false, default: "default"
      t.integer :last_number, null: false, default: 1
      t.timestamps
    end

    add_index :invoice_sequences, [ :account_id, :scope ], unique: true

    # Drafts are unnumbered until sent, so invoice_number becomes nullable. The
    # existing unique index on [account_id, invoice_number] stays as-is: SQLite
    # treats NULLs as distinct in a unique index, so unlimited unnumbered drafts
    # are allowed while sent invoices remain collision-checked.
    change_column_null :invoices, :invoice_number, true

    # Backfill one "default" sequence per account holding the last issued number
    # (the next call returns last_number + 1). The digit-run extraction mirrors
    # the old generator's format (PREFIX-0001); existing data always used a
    # digit-free prefix, so this is safe as a one-time backfill. Accounts with no
    # invoices get no row — the sequence is created lazily on first allocation.
    Account.find_each do |account|
      max = account.invoices.where.not(invoice_number: nil)
        .pluck(:invoice_number)
        .map { |number| number[/\d+/].to_i }
        .max || 0
      next if max.zero?

      account.invoice_sequences.create!(scope: "default", last_number: max)
    end
  end

  def down
    # Restore non-null on invoice_number only after renumbering any drafts; as a
    # safety valve, refuse to reverse if unnumbered drafts exist.
    if Invoice.where(status: 0, invoice_number: nil).exists?
      raise ActiveRecord::IrreversibleMigration, "Unnumbered drafts exist — restore their numbers before reversing."
    end

    drop_table :invoice_sequences
    change_column_null :invoices, :invoice_number, false
  end
end
