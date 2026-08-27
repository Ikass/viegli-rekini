# frozen_string_literal: true

module InvoiceCodes
  extend ActiveSupport::Concern

  UNIT_CODES = {
    "C62" => "Piece",
    "HUR" => "Hour",
    "DAY" => "Day",
    "WEE" => "Week",
    "MON" => "Month",
    "QAN" => "Quarter",
    "ANN" => "Year",
    "KGM" => "Kilogram",
    "LTR" => "Litre",
    "MTR" => "Metre",
    "PK" => "Pack",
    "MTK" => "Square metre"
  }.freeze

  TAX_CATEGORY_CODES = {
    "S" => "Standard rate — 21% (S)",
    "S12" => "Reduced rate — 12% (S)",
    "S5" => "Reduced rate — 5% (S)",
    "Z" => "Zero rated (Z)",
    "E" => "Exempt from tax (E)",
    "AE" => "Reverse charge (AE)",
    "G" => "Out of scope (G)"
  }.freeze

  # Compact labels for tight layouts (e.g. the line-items editor table),
  # where the full descriptive label is too wide.
  SHORT_TAX_CATEGORY_CODES = {
    "S" => "21% (S)",
    "S12" => "12% (S12)",
    "S5" => "5% (S5)",
    "Z" => "0% (Z)",
    "E" => "0% (E)",
    "AE" => "0% (AE)",
    "G" => "0% (G)"
  }.freeze
end
