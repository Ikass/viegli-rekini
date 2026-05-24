# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :default_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :default_vat_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }

  attribute :default_price, :string

  def default_price
    default_price_cents ? format("%.2f", default_price_cents / 100.0) : nil
  end

  def default_price=(value)
    if value.present?
      self.default_price_cents = (value.to_s.delete(",").to_f * 100).round
    end
  end
end
