# frozen_string_literal: true

require "builder"

# Renders an Invoice as a UBL 2.1 document for the EN 16931 semantic model.
#
# This is a pure renderer, not a state transition — it follows the InvoicePdf
# shape (constructor + public reader + filename), not the Result-struct service
# object shape from agents/docs/contracts/service-objects.md.
#
# Scope is deliberately the EN 16931 profile, not PEPPOL BIS 3.0: PEPPOL
# requires a seller/buyer cbc:EndpointID with an EAS schemeID (rule
# PEPPOL-EN16931-R010) that the app has no data for yet. When e-adrese/endpoint
# data exists, switch CustomizationID/ProfileID and add EndpointID here.
class UblInvoiceBuilder
  CUSTOMIZATION_ID = "urn:cen.eu:en16931:2017"
  PROFILE_ID = "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0"
  INVOICE_TYPE_CODE = "380" # UNCL1001: commercial invoice
  CURRENCY = "EUR"
  VAT_TAX_SCHEME_ID = "VAT"
  DEFAULT_COUNTRY_CODE = "LV"
  PAYMENT_MEANS_CODE = "30" # UNCL4461: credit transfer

  NAMESPACES = {
    "xmlns" => "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
    "xmlns:cac" => "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
    "xmlns:cbc" => "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
  }.freeze

  # Internal tax-category codes → UNCL5305 codes. The app uses "S12"/"S5" as
  # internal reduced-rate markers; UNCL5305 calls all of these "S", carrying the
  # actual rate in Percent (BT-118).
  # Mapping now lives in InvoiceCodes#tax_category_for (single source of truth).

  def initialize(invoice)
    @invoice = invoice
    @account = invoice.account
    @client = invoice.client
  end

  def to_xml
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct!
    xml.tag!("Invoice", NAMESPACES) do
      header(xml)
      accounting_supplier_party(xml)
      accounting_customer_party(xml)
      payment_means(xml)
      payment_terms(xml)
      tax_total(xml)
      legal_monetary_total(xml)

      @invoice.line_items.each_with_index do |item, index|
        invoice_line(xml, item, index + 1)
      end
    end
    xml.target!
  end

  def filename
    "#{@invoice.invoice_number}.xml"
  end

  private

  def header(xml)
    xml.tag!("cbc:CustomizationID", CUSTOMIZATION_ID)
    xml.tag!("cbc:ProfileID", PROFILE_ID)
    xml.tag!("cbc:ID", @invoice.invoice_number)
    xml.tag!("cbc:IssueDate", @invoice.issued_on.iso8601)
    xml.tag!("cbc:DueDate", @invoice.due_on.iso8601)
    xml.tag!("cbc:InvoiceTypeCode", INVOICE_TYPE_CODE)
    xml.tag!("cbc:DocumentCurrencyCode", CURRENCY)
    xml.tag!("cbc:Note", @invoice.notes) if @invoice.notes.present?
  end

  def accounting_supplier_party(xml)
    xml.tag!("cac:AccountingSupplierParty") do
      xml.tag!("cac:Party") do
        xml.tag!("cac:PartyName") do
          xml.tag!("cbc:Name", party_name(@account))
        end
        # Account has no country_code column yet; the MVP seller is always Latvian.
        postal_address(xml,
          street: @account.address,
          city: @account.city,
          postal_zone: @account.postal_code,
          country_code: DEFAULT_COUNTRY_CODE)

        if @account.vat_number.present?
          xml.tag!("cac:PartyTaxScheme") do
            xml.tag!("cbc:CompanyID", @account.vat_number)
            tax_scheme(xml)
          end
        end

        xml.tag!("cac:PartyLegalEntity") do
          xml.tag!("cbc:RegistrationName", party_name(@account))
          if @account.registration_number.present?
            xml.tag!("cbc:CompanyID", @account.registration_number)
          end
        end
      end
    end
  end

  def accounting_customer_party(xml)
    xml.tag!("cac:AccountingCustomerParty") do
      xml.tag!("cac:Party") do
        xml.tag!("cac:PartyName") do
          xml.tag!("cbc:Name", party_name(@client))
        end
        postal_address(xml,
          street: @client.address,
          city: @client.city,
          postal_zone: @client.postal_code,
          country_code: @client.country_code.presence || DEFAULT_COUNTRY_CODE)

        if @client.vat_number.present?
          xml.tag!("cac:PartyTaxScheme") do
            xml.tag!("cbc:CompanyID", @client.vat_number)
            tax_scheme(xml)
          end
        end

        xml.tag!("cac:PartyLegalEntity") do
          xml.tag!("cbc:RegistrationName", party_name(@client))
          if @client.registration_number.present?
            xml.tag!("cbc:CompanyID", @client.registration_number)
          end
        end
      end
    end
  end

  def postal_address(xml, street:, city:, postal_zone:, country_code:)
    xml.tag!("cac:PostalAddress") do
      xml.tag!("cbc:StreetName", street) if street.present?
      xml.tag!("cbc:CityName", city) if city.present?
      xml.tag!("cbc:PostalZone", postal_zone) if postal_zone.present?
      xml.tag!("cac:Country") do
        xml.tag!("cbc:IdentificationCode", country_code)
      end
    end
  end

  def payment_means(xml)
    return if @account.bank_account.blank?

    xml.tag!("cac:PaymentMeans") do
      xml.tag!("cbc:PaymentMeansCode", PAYMENT_MEANS_CODE)
      xml.tag!("cbc:PaymentDueDate", @invoice.due_on.iso8601)
      xml.tag!("cac:PayeeFinancialAccount") do
        xml.tag!("cbc:ID", @account.bank_account)
        xml.tag!("cbc:Name", @account.bank_name) if @account.bank_name.present?
        if @account.bank_swift.present?
          xml.tag!("cac:FinancialInstitutionBranch") do
            xml.tag!("cbc:ID", @account.bank_swift)
          end
        end
      end
    end
  end

  def payment_terms(xml)
    return if @account.payment_terms.blank?

    xml.tag!("cac:PaymentTerms") do
      xml.tag!("cbc:Note", @account.payment_terms)
    end
  end

  def tax_total(xml)
    xml.tag!("cac:TaxTotal") do
      xml.tag!("cbc:TaxAmount", amount(@invoice.vat_total), "currencyID" => CURRENCY)

      @invoice.vat_breakdown.each do |(category, rate), group|
        xml.tag!("cac:TaxSubtotal") do
          xml.tag!("cbc:TaxableAmount", amount(group[:taxable_cents]), "currencyID" => CURRENCY)
          xml.tag!("cbc:TaxAmount", amount(group[:vat_cents]), "currencyID" => CURRENCY)
          xml.tag!("cac:TaxCategory") do
            xml.tag!("cbc:ID", category)
            xml.tag!("cbc:Percent", decimal(rate))
            tax_scheme(xml)
          end
        end
      end
    end
  end

  def legal_monetary_total(xml)
    xml.tag!("cac:LegalMonetaryTotal") do
      xml.tag!("cbc:LineExtensionAmount", amount(@invoice.subtotal), "currencyID" => CURRENCY)
      xml.tag!("cbc:TaxExclusiveAmount", amount(@invoice.subtotal), "currencyID" => CURRENCY)
      xml.tag!("cbc:TaxInclusiveAmount", amount(@invoice.total), "currencyID" => CURRENCY)
      xml.tag!("cbc:PayableAmount", amount(@invoice.total), "currencyID" => CURRENCY)
    end
  end

  def invoice_line(xml, item, position)
    xml.tag!("cac:InvoiceLine") do
      xml.tag!("cbc:ID", position)
      xml.tag!("cbc:InvoicedQuantity", decimal(item.quantity), "unitCode" => item.unit_code)
      xml.tag!("cbc:LineExtensionAmount", amount(item.subtotal), "currencyID" => CURRENCY)

      xml.tag!("cac:Item") do
        xml.tag!("cbc:Name", item.description)
        xml.tag!("cac:ClassifiedTaxCategory") do
          xml.tag!("cbc:ID", InvoiceCodes.tax_category_for(item.tax_category_code))
          xml.tag!("cbc:Percent", decimal(item.vat_rate))
          tax_scheme(xml)
        end
      end

      xml.tag!("cac:Price") do
        xml.tag!("cbc:PriceAmount", amount(item.unit_price_cents), "currencyID" => CURRENCY)
      end
    end
  end

  def tax_scheme(xml)
    xml.tag!("cac:TaxScheme") do
      xml.tag!("cbc:ID", VAT_TAX_SCHEME_ID)
    end
  end

  # Amounts are read from Invoice#subtotal/vat_total/total, which compute in
  # Ruby over the line items (integer cents) — the single source of truth. See
  # agents/docs/recipes/money-calculations.md.

  # Integer cents → exact decimal string ("123.45"), never float arithmetic.
  def amount(cents)
    cents = cents.to_i
    sign = cents.negative? ? "-" : ""
    whole, fraction = cents.abs.divmod(100)
    format("%s%d.%02d", sign, whole, fraction)
  end

  # BigDecimal/decimal → trimmed decimal string ("21.0" → "21", "10.50" → "10.5").
  def decimal(value)
    string = BigDecimal(value.to_s).to_s("F")
    return string unless string.include?(".")
    string.sub(/0+\z/, "").sub(/\.\z/, "")
  end

  def party_name(record)
    record.company_name.presence || record.name
  end
end
