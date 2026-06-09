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

  private

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
