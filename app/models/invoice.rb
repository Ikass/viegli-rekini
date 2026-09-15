# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :account
  belongs_to :client
  has_many :line_items, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: proc { |attrs| attrs["description"].blank? }

  enum :status, { draft: 0, sent: 1, paid: 2, void: 3 }, default: :draft

  validates :invoice_number, presence: true
  validates :issued_on, presence: true
  validates :due_on, presence: true
  validate :client_belongs_to_account

  before_validation :generate_invoice_number, on: :create

  # Pure calculation methods — no DB writes.
  # Use SQL SUM so calculations happen in the database, not in Ruby.
  def subtotal
    line_items.sum("quantity * unit_price_cents")
  end

  def vat_total
    line_items.sum("ROUND(quantity * unit_price_cents * vat_rate / 100)")
  end

  def total
    subtotal + vat_total
  end

  def vat_regime_note
    return nil if account.vat_number.blank?
    client.vat_regime_note
  end

  # Derived state — not a persisted status. An invoice is overdue when it has
  # been sent but its due date has passed without payment.
  def overdue?
    sent? && due_on < Date.current
  end

  # The status to surface in the UI, collapsing the derived "overdue" condition
  # into the same vocabulary as the persisted enum (draft/sent/overdue/paid/void).
  def display_status
    overdue? ? "overdue" : status
  end

  private

  def client_belongs_to_account
    return unless client && account_id
    errors.add(:client, "must belong to your account") unless client.account_id == account_id
  end

  def generate_invoice_number
    return if invoice_number.present?

    account.with_lock do
      last_number = account.invoices
        .pluck(:invoice_number)
        .compact
        .max_by { |n| n[/\d+/].to_i }

      next_sequence = if last_number
        last_number[/\d+/].to_i + 1
      else
        1
      end

      self.invoice_number = "#{account.invoice_prefix}-#{next_sequence.to_s.rjust(account.invoice_number_padding, "0")}"
    end
  end
end
