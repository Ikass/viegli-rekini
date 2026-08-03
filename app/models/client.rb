# frozen_string_literal: true

class Client < ApplicationRecord
  belongs_to :account
  has_many :invoices, dependent: :destroy

  validates :name, presence: true

  enum :delivery_channel, { email: 0, e_adrese: 1 }, default: :email
  enum :vat_regime, { standard: 0, reverse_charge: 1, export: 2 }, default: :standard

  def vat_regime_note
    case vat_regime&.to_sym
    when :reverse_charge
      "Reverse charge applies — VAT payable by the recipient (PVN likums Art. 138)"
    when :export
      "Export of goods/services — VAT 0% applies (PVN likums Art. 46)"
    else
      nil
    end
  end

  # Sort clients alphabetically by name by default.
  # This is a "default scope" — it applies to all queries unless overridden.
  # Useful here because client dropdowns and lists should always be alphabetical.
  default_scope { order(:name) }
end
