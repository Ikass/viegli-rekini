# frozen_string_literal: true

require "test_helper"

class ScrubInvoiceDataTest < ActiveSupport::TestCase
  IBAN = "LV12HABA0001234567890"

  test "scrub_hash replaces sensitive keys with placeholders" do
    hash = { iban: IBAN, "client_name" => "Acme SIA", notes: "kept" }

    ScrubInvoiceData.scrub_hash(hash)

    assert_equal "[FILTERED]", hash[:iban]
    assert_equal "[FILTERED]", hash["client_name"]
    assert_equal "kept", hash[:notes]
  end

  test "scrub_hash recurses into nested hashes and arrays" do
    hash = { account: { bank_account: IBAN, name: "SIA" }, ibans: [ IBAN, "keep" ] }

    ScrubInvoiceData.scrub_hash(hash)

    assert_equal "[FILTERED]", hash[:account][:bank_account]
    assert_equal [ "[FILTERED]", "keep" ], hash[:ibans]
  end

  test "scrub_hash scrubs IBANs in string values" do
    hash = { description: "paid to #{IBAN} today" }

    ScrubInvoiceData.scrub_hash(hash)

    assert_equal "paid to [FILTERED] today", hash[:description]
  end

  test "scrub_string replaces IBANs and leaves other text alone" do
    assert_equal "x [FILTERED] y", ScrubInvoiceData.scrub_string("x #{IBAN} y")
    assert_equal "no bank data", ScrubInvoiceData.scrub_string("no bank data")
  end

  test "sensitive_key? is case-insensitive" do
    assert ScrubInvoiceData.sensitive_key?("iban")
    assert ScrubInvoiceData.sensitive_key?("VAT_NUMBER")
    assert_not ScrubInvoiceData.sensitive_key?("description")
  end

  test "scrub_request scrubs data, query string, and cookies" do
    request = Struct.new(:data, :query_string, :cookies)
                   .new({ vat_number: "LV40001234567" }, "iban=#{IBAN}", { client_name: "Acme" })

    ScrubInvoiceData.scrub_request(request)

    assert_equal "[FILTERED]", request.data[:vat_number]
    assert_equal "iban=[FILTERED]", request.query_string
    assert_equal "[FILTERED]", request.cookies[:client_name]
  end

  test "scrub_breadcrumbs scrubs crumb data" do
    crumb = Sentry::Breadcrumb.new(category: "log", message: "paid", data: { iban: IBAN })
    buffer = Sentry::BreadcrumbBuffer.new
    buffer.record(crumb)

    ScrubInvoiceData.scrub_breadcrumbs(buffer)

    assert_equal "[FILTERED]", crumb.data[:iban]
  end

  test "scrub_exceptions scrubs exception messages" do
    single = Struct.new(:value).new("failed for #{IBAN}")
    exception_interface = Struct.new(:values).new([ single ])
    event = Struct.new(:exception).new(exception_interface)

    ScrubInvoiceData.scrub_exceptions(event)

    assert_equal "failed for [FILTERED]", single.value
  end

  test "call scrubs extra and message on a real event" do
    event = Sentry::Event.new(configuration: Sentry::Configuration.new)
    event.extra = { client: { iban: IBAN, vat_number: "LV40001234567" }, note: "kept" }
    event.message = "invoice #{IBAN} failed"

    result = ScrubInvoiceData.call(event)

    assert_same event, result
    assert_equal "[FILTERED]", event.extra[:client][:iban]
    assert_equal "[FILTERED]", event.extra[:client][:vat_number]
    assert_equal "invoice [FILTERED] failed", event.message
  end
end
