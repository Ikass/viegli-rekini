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
end
