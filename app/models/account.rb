# frozen_string_literal: true

class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :invoice_sequences, dependent: :destroy

  validates :name, presence: true
  validates :invoice_number_padding, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
end
