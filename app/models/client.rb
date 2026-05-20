# frozen_string_literal: true

class Client < ApplicationRecord
  belongs_to :account
  has_many :invoices, dependent: :destroy

  validates :name, presence: true

  # Sort clients alphabetically by name by default.
  # This is a "default scope" — it applies to all queries unless overridden.
  # Useful here because client dropdowns and lists should always be alphabetical.
  default_scope { order(:name) }
end
