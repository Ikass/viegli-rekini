# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_09_151457) do
  create_table "accounts", force: :cascade do |t|
    t.string "address"
    t.string "bank_account"
    t.string "bank_name"
    t.string "bank_swift"
    t.string "city"
    t.string "company_name"
    t.string "country", default: "Latvia"
    t.datetime "created_at", null: false
    t.integer "invoice_number_padding", default: 4, null: false
    t.string "invoice_prefix", default: "INV", null: false
    t.string "name", null: false
    t.text "payment_terms"
    t.string "postal_code"
    t.string "registration_number"
    t.datetime "updated_at", null: false
    t.string "vat_number"
  end

  create_table "clients", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "address"
    t.string "city"
    t.string "company_name"
    t.string "country", default: "Latvia"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.integer "delivery_channel", default: 0, null: false
    t.string "e_adrese_id"
    t.string "email"
    t.string "iban"
    t.boolean "is_budget_institution", default: false, null: false
    t.string "name", null: false
    t.string "postal_code"
    t.datetime "updated_at", null: false
    t.string "vat_number"
    t.index ["account_id"], name: "index_clients_on_account_id"
    t.check_constraint "delivery_channel IN (0, 1)", name: "clients_delivery_channel_check"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.string "invoice_number", null: false
    t.date "issued_on", null: false
    t.text "notes"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "invoice_number"], name: "index_invoices_on_account_id_and_invoice_number", unique: true
    t.index ["account_id"], name: "index_invoices_on_account_id"
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.check_constraint "status IN (0, 1, 2, 3)", name: "invoices_status_check"
  end

  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "invoice_id", null: false
    t.integer "position"
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.decimal "vat_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
  end

  create_table "products", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "default_price_cents", default: 0, null: false
    t.decimal "default_vat_rate", precision: 5, scale: 2, default: "21.0", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_products_on_account_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "clients", "accounts"
  add_foreign_key "invoices", "accounts"
  add_foreign_key "invoices", "clients"
  add_foreign_key "line_items", "invoices"
  add_foreign_key "products", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "accounts"
end
