# frozen_string_literal: true

require "test_helper"

class UblInvoiceBuilderTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @account.update!(
      company_name: "SIA Test",
      registration_number: "40001234567",
      vat_number: "LV40001234567",
      address: "Brīvības iela 100",
      city: "Rīga",
      postal_code: "LV-1001",
      country: "Latvija",
      bank_name: "Swedbank",
      bank_account: "LV12HABA0001234567890",
      bank_swift: "HABALV22",
      payment_terms: "Payment within 14 days"
    )

    @client = clients(:one)
    @client.update!(
      name: "SIA Klients",
      company_name: "SIA Klients",
      registration_number: "40007654321",
      vat_number: "LV40007654321",
      address: "Krasta iela 5",
      city: "Rīga",
      postal_code: "LV-1019",
      country_code: "LV"
    )

    @invoice = @account.invoices.create!(
      client: @client,
      invoice_number: "INV-UBL1",
      issued_on: Date.new(2026, 10, 1),
      due_on: Date.new(2026, 10, 15),
      notes: "Thank you"
    )
    @invoice.line_items.create!(description: "Consulting", quantity: 2, unit_code: "HUR", unit_price_cents: 5000, tax_category_code: "S", vat_rate: 21, position: 0)
    @invoice.line_items.create!(description: "Printing", quantity: 1, unit_code: "C62", unit_price_cents: 10_000, tax_category_code: "S12", vat_rate: 12, position: 1)
  end

  test "produces well-formed XML with the Peppol BIS 3.0 customization id" do
    document = Nokogiri::XML(build)

    assert_empty document.errors
    assert_equal "urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0", document.at_xpath("//*[local-name()='CustomizationID']").text
    assert_equal "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0", document.at_xpath("//*[local-name()='ProfileID']").text
  end

  test "renders the header fields" do
    assert_equal "INV-UBL1", text("//ID")
    assert_equal "2026-10-01", text("//IssueDate")
    assert_equal "2026-10-15", text("//DueDate")
    assert_equal "380", text("//InvoiceTypeCode")
    assert_equal "EUR", text("//DocumentCurrencyCode")
    assert_equal "Thank you", text("//Note")
  end

  test "renders the seller party" do
    scope = "//AccountingSupplierParty//Party"
    assert_equal "SIA Test", text("#{scope}/PartyName/Name")
    assert_equal "40001234567", text("#{scope}/PartyLegalEntity/CompanyID")
    assert_equal "LV40001234567", text("#{scope}/PartyTaxScheme/CompanyID")
    assert_equal "LV", text("#{scope}/PostalAddress/Country/IdentificationCode")
  end

  test "renders the buyer party" do
    scope = "//AccountingCustomerParty//Party"
    assert_equal "SIA Klients", text("#{scope}/PartyName/Name")
    assert_equal "40007654321", text("#{scope}/PartyLegalEntity/CompanyID")
    assert_equal "LV40007654321", text("#{scope}/PartyTaxScheme/CompanyID")
  end

  test "renders payment means and terms" do
    assert_equal "30", text("//PaymentMeans/PaymentMeansCode")
    assert_equal "LV12HABA0001234567890", text("//PayeeFinancialAccount/ID")
    assert_equal "SIA Test", text("//PayeeFinancialAccount/Name")
    assert_equal "HABALV22", text("//FinancialInstitutionBranch/ID")
    assert_equal "Payment within 14 days", text("//PaymentTerms/Note")
  end

  test "does not emit PaymentDueDate inside PaymentMeans" do
    assert_nil document.at_xpath("//PaymentDueDate")
  end

  test "emits seller and buyer EndpointID as the first Party child with the correct schemeID" do
    seller_party = document.at_xpath("//AccountingSupplierParty//Party")
    assert_equal "EndpointID", seller_party.element_children.first.name
    assert_equal "LV40001234567", seller_party.at_xpath("./EndpointID").text
    assert_equal "9939", seller_party.at_xpath("./EndpointID").attribute("schemeID").value

    buyer_party = document.at_xpath("//AccountingCustomerParty//Party")
    assert_equal "EndpointID", buyer_party.element_children.first.name
    assert_equal "LV40007654321", buyer_party.at_xpath("./EndpointID").text
    assert_equal "9939", buyer_party.at_xpath("./EndpointID").attribute("schemeID").value
  end

  test "falls back to the registration number for the buyer endpoint when there is no VAT number" do
    @client.update!(vat_number: nil, registration_number: "40007654321")

    buyer_party = document.at_xpath("//AccountingCustomerParty//Party")
    assert_equal "40007654321", buyer_party.at_xpath("./EndpointID").text
    assert_equal "0218", buyer_party.at_xpath("./EndpointID").attribute("schemeID").value
  end

  test "returns nil buyer endpoint when the buyer has neither VAT nor registration number" do
    @client.update!(vat_number: nil, registration_number: nil)

    assert_nil UblInvoiceBuilder.new(@invoice).buyer_endpoint_id
  end

  test "adds the Latvian registration schemeID to PartyLegalEntity CompanyID" do
    seller_legal = document.at_xpath("//AccountingSupplierParty//PartyLegalEntity/CompanyID")
    assert_equal "40001234567", seller_legal.text
    assert_equal "0218", seller_legal.attribute("schemeID").value
  end

  test "emits the buyer reference, falling back to N/A when blank" do
    assert_equal "N/A", stripped.at_xpath("//BuyerReference").text

    @invoice.update!(buyer_reference: "PO-1234")

    assert_equal "PO-1234", stripped.at_xpath("//BuyerReference").text
  end

  test "reconciles totals computed from the XML itself" do
    doc = stripped

    line_total = doc.xpath("//InvoiceLine/LineExtensionAmount").sum { |n| BigDecimal(n.text) }
    subtotal_sum = doc.xpath("//TaxSubtotal/TaxAmount").sum { |n| BigDecimal(n.text) }
    tax_total = BigDecimal(doc.at_xpath("//TaxTotal/TaxAmount").text)
    line_extension_total = BigDecimal(doc.at_xpath("//LegalMonetaryTotal/LineExtensionAmount").text)
    tax_exclusive = BigDecimal(doc.at_xpath("//LegalMonetaryTotal/TaxExclusiveAmount").text)
    tax_inclusive = BigDecimal(doc.at_xpath("//LegalMonetaryTotal/TaxInclusiveAmount").text)
    payable = BigDecimal(doc.at_xpath("//LegalMonetaryTotal/PayableAmount").text)

    assert_equal line_extension_total, line_total
    assert_equal tax_total, subtotal_sum
    assert_equal tax_exclusive + tax_total, tax_inclusive
    assert_equal tax_inclusive, payable
  end

  test "groups tax subtotals by mapped UNCL5305 category and rate" do
    subtotals = nodes("//TaxSubtotal")

    assert_equal 2, subtotals.size
    assert_equal %w[S S], subtotals.map { |node| node.at_xpath(".//ID").text }
    assert_equal %w[21 12], subtotals.map { |node| node.at_xpath(".//Percent").text }
  end

  test "reconciles monetary totals to the cent" do
    assert_equal "33.00", text("//TaxTotal/TaxAmount")
    assert_equal "200.00", text("//LegalMonetaryTotal/LineExtensionAmount")
    assert_equal "200.00", text("//LegalMonetaryTotal/TaxExclusiveAmount")
    assert_equal "233.00", text("//LegalMonetaryTotal/TaxInclusiveAmount")
    assert_equal "233.00", text("//LegalMonetaryTotal/PayableAmount")
  end

  test "rounds VAT once per category, not per line" do
    invoice = @account.invoices.create!(
      client: @client,
      invoice_number: "INV-UBL2",
      issued_on: Date.new(2026, 10, 1),
      due_on: Date.new(2026, 10, 15)
    )
    3.times do
      invoice.line_items.create!(description: "1c line", quantity: 1, unit_code: "C62", unit_price_cents: 1, tax_category_code: "S", vat_rate: 21)
    end

    builder = UblInvoiceBuilder.new(invoice)
    doc = Nokogiri::XML(builder.to_xml)
    doc.remove_namespaces!

    assert_equal "0.03", doc.at_xpath("//TaxSubtotal/TaxableAmount").text
    assert_equal "0.01", doc.at_xpath("//TaxSubtotal/TaxAmount").text
    assert_equal "0.01", doc.at_xpath("//TaxTotal/TaxAmount").text
    assert_equal "0.04", doc.at_xpath("//LegalMonetaryTotal/TaxInclusiveAmount").text
    assert_equal "0.04", doc.at_xpath("//LegalMonetaryTotal/PayableAmount").text
  end

  test "separates the VATable amounts by rate" do
    subtotals = nodes("//TaxSubtotal")

    assert_equal %w[100.00 100.00], subtotals.map { |node| node.at_xpath(".//TaxableAmount").text }
    assert_equal %w[21.00 12.00], subtotals.map { |node| node.at_xpath(".//TaxAmount").text }
  end

  test "renders invoice lines with unit codes and prices" do
    lines = nodes("//InvoiceLine")

    assert_equal 2, lines.size
    first = lines.first
    assert_equal "2", first.at_xpath(".//InvoicedQuantity").text
    assert_equal "HUR", first.at_xpath(".//InvoicedQuantity").attribute("unitCode").value
    assert_equal "50.00", first.at_xpath(".//Price/PriceAmount").text
    assert_equal "100.00", first.at_xpath(".//LineExtensionAmount").text
  end

  test "omits the seller VAT scheme when the issuer is not VAT-registered" do
    @account.update!(vat_number: nil)

    document = Nokogiri::XML(build)
    document.remove_namespaces!

    assert_nil document.at_xpath("//AccountingSupplierParty//PartyTaxScheme")
  end

  test "escapes XML-special characters in text nodes" do
    @client.update!(company_name: 'A & B <Ltd> "x"')

    document = Nokogiri::XML(build)

    assert_empty document.errors
    assert_equal 'A & B <Ltd> "x"', document.at_xpath("//*[local-name()='AccountingCustomerParty']//*[local-name()='Name']").text
  end

  test "filename is based on the invoice number" do
    assert_equal "INV-UBL1.xml", UblInvoiceBuilder.new(@invoice).filename
  end

  private

  def build
    UblInvoiceBuilder.new(@invoice).to_xml
  end

  def document
    @document ||= begin
      doc = Nokogiri::XML(build)
      doc.remove_namespaces!
      doc
    end
  end

  # Fresh namespace-stripped document (not memoized) — for tests that mutate the
  # invoice mid-test and need to re-read the XML.
  def stripped
    doc = Nokogiri::XML(build)
    doc.remove_namespaces!
    doc
  end

  def nodes(xpath)
    document.xpath(xpath)
  end

  def text(xpath)
    document.at_xpath(xpath).text
  end
end
