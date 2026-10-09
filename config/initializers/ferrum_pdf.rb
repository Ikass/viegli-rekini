# frozen_string_literal: true

FerrumPdf.configure do |config|
  # Honour the page geometry declared in the print layout's `@page` rule
  # (A4, 15mm/20mm margins) and render background graphics (tables, badges).
  config.pdf_options.prefer_css_page_size = true
  config.pdf_options.print_background = true

  # Production (Kamal/OVHCloud) will need Chromium installed and the sandbox
  # disabled inside the container — deferred to the deploy session:
  #
  #   config.browser_path = "/usr/bin/chromium"
  #   config.browser_options = { "no-sandbox" => true }
end
