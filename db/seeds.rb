# frozen_string_literal: true

return if Rails.env.test?

user = User.find_by(email_address: DemoAccount::EMAIL)

if user
  puts "Demo account already exists — skipping seed."
  return
end

ActiveRecord::Base.transaction do
  account = Account.create!(
    name: "Demo Uzņēmums",
    company_name: "SIA Demo Uzņēmums",
    registration_number: "LV40001234567",
    vat_number: "LV40001234567",
    address: "Brīvības iela 100",
    city: "Rīga",
    postal_code: "LV-1001",
    country: "Latvija",
    bank_name: "Swedbank",
    bank_account: "LV12HABA0001234567890",
    bank_swift: "HABALV22",
    invoice_prefix: "INV",
    invoice_number_padding: 4,
    payment_terms: "14 days net"
  )

  User.create!(
    email_address: DemoAccount::EMAIL,
    password: DemoAccount::PASSWORD,
    password_confirmation: DemoAccount::PASSWORD,
    account: account
  )

  clients = [
    { name: "Jānis Bērziņš", company_name: "Bērziņa Konsultācijas", email: "janis@berzins.lv", vat_number: "LV98765432101", address: "Kr. Barona iela 25", city: "Rīga", postal_code: "LV-1011", country: "Latvija", country_code: "LV", delivery_channel: :email, iban: "LV12HABA0001234567890", e_adrese_id: "90000000001" },
    { name: "Ilze Ozoliņa", company_name: "Ozoliņa Dizains", email: "ilze@ozolina.lv", vat_number: "LV12345678901", address: "Lāčplēša iela 70", city: "Rīga", postal_code: "LV-1002", country: "Latvija", country_code: "LV", delivery_channel: :email },
    { name: "Mārtiņš Liepiņš", email: "martins@liepins.lv", address: "Rīgas iela 15", city: "Cēsis", postal_code: "LV-4101", country: "Latvija", country_code: "LV", delivery_channel: :email },
    { name: "SIA Zaļā Enerģija", company_name: "SIA Zaļā Enerģija", email: "info@zalaenergija.lv", vat_number: "LV56789012345", address: "Ventspils iela 3", city: "Ventspils", postal_code: "LV-3601", country: "Latvija", country_code: "LV", delivery_channel: :email }
  ].map { |attrs| account.clients.create!(attrs) }

  products = [
    { name: "Konsultāciju stunda", description: "Biznesa konsultācija 1 stunda", default_price_cents: 12000, default_vat_rate: 21, unit_code: "HUR", tax_category_code: "S" },
    { name: "Mājas lapas izstrāde", description: "Vienas lapas tīmekļa vietne", default_price_cents: 50000, default_vat_rate: 21, unit_code: "C62", tax_category_code: "S" },
    { name: "Gada grāmatvedības pārskats", description: "Gada pārskata sagatavošana", default_price_cents: 35000, default_vat_rate: 21, unit_code: "C62", tax_category_code: "S" },
    { name: "IT atbalsts mēnesī", description: "IT sistēmu uzturēšana un atbalsts", default_price_cents: 8000, default_vat_rate: 21, unit_code: "C62", tax_category_code: "S" },
    { name: "Apgrozījuma aprēķins", description: "Mēneša apgrozījuma atskaite", default_price_cents: 4500, default_vat_rate: 0, unit_code: "C62", tax_category_code: "Z" },
    { name: "Dizaina koncepts", description: "Vizuālās identitātes izstrāde", default_price_cents: 25000, default_vat_rate: 21, unit_code: "C62", tax_category_code: "S" }
  ].map { |attrs| account.products.create!(attrs) }

  today = Date.current

  invoice_data = [
    { status: :draft, client: clients[0], days_ago: 2, due_days: 12, notes: "Melnraksts — vēl jāpārskata.", items: [
      { product: products[0], quantity: 3 },
      { product: products[4], quantity: 1 }
    ] },
    { status: :sent, client: clients[1], days_ago: 10, due_days: 4, notes: "Atgādinājums nosūtīts 2026-05-20.", items: [
      { product: products[1], quantity: 1 },
      { product: products[5], quantity: 2 },
      { product: products[0], quantity: 1 }
    ] },
    { status: :sent, client: clients[2], days_ago: 5, due_days: 9, items: [
      { product: products[2], quantity: 1 },
      { product: products[3], quantity: 3 }
    ] },
    { status: :paid, client: clients[0], days_ago: 30, due_days: -16, items: [
      { product: products[4], quantity: 2 },
      { product: products[0], quantity: 2 }
    ] },
    { status: :paid, client: clients[3], days_ago: 45, due_days: -31, notes: "Apmaksāts ar pārskaitījumu.", items: [
      { product: products[3], quantity: 6 },
      { product: products[1], quantity: 1 }
    ] },
    { status: :void, client: clients[1], days_ago: 20, due_days: -6, notes: "Anulēts pēc klienta pieprasījuma.", items: [
      { product: products[5], quantity: 1 }
    ] }
  ]

  invoice_data.each do |data|
    invoice = account.invoices.create!(
      client: data[:client],
      issued_on: today - data[:days_ago],
      due_on: today + data[:due_days],
      status: data[:status],
      notes: data[:notes]
    )

    data[:items].each_with_index do |item_data, idx|
      product = item_data[:product]
      invoice.line_items.create!(
        description: product.description || product.name,
        quantity: item_data[:quantity],
        unit_code: product.unit_code,
        unit_price_cents: product.default_price_cents,
        tax_category_code: product.tax_category_code,
        vat_rate: product.default_vat_rate,
        position: idx
      )
    end
  end

  total_invoices = account.invoices.count
  total_clients = account.clients.count
  total_products = account.products.count

  puts "Seed complete: #{total_clients} clients, #{total_products} products, #{total_invoices} invoices created."
  puts "Sign in with #{DemoAccount::EMAIL} / #{DemoAccount::PASSWORD}"
end
