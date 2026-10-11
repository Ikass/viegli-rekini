# frozen_string_literal: true

class InvoiceSequence < ApplicationRecord
  DEFAULT_SCOPE = "default"

  belongs_to :account

  validates :scope, presence: true, uniqueness: { scope: :account_id }
  validates :last_number, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Atomically allocate and format the next invoice number for an account's
  # sequence. The INSERT ... ON CONFLICT ... UPDATE is a single statement that
  # SQLite serializes, so no explicit lock is needed. Call inside the invoice's
  # own transaction so the bump and the invoice save commit or roll back together
  # (gapless on failure).
  #
  # last_number holds the most recently issued number: the first allocation
  # inserts 1, each subsequent conflict bumps it and returns the bumped value.
  def self.next_for!(account, scope = DEFAULT_SCOPE)
    last_number = bump_last_number!(account, scope)
    format_number(account, last_number)
  end

  def self.format_number(account, last_number)
    "#{account.invoice_prefix}-#{last_number.to_s.rjust(account.invoice_number_padding, "0")}"
  end

  def self.bump_last_number!(account, scope)
    quoted_account_id = connection.quote(account.id)
    quoted_scope = connection.quote(scope)

    # exec_query (not select_value/select_all) — those mis-handle an UPSERT's
    # RETURNING and return the stale value without incrementing.
    connection.exec_query(<<~SQL, "Next invoice number").rows.first.first.to_i
      INSERT INTO invoice_sequences (account_id, scope, last_number, created_at, updated_at)
      VALUES (#{quoted_account_id}, #{quoted_scope}, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (account_id, scope)
      DO UPDATE SET last_number = invoice_sequences.last_number + 1
      RETURNING last_number
    SQL
  end

  private_class_method :bump_last_number!
end
