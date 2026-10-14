# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # Invoice data must not reach logs or Sentry (ANALYTICS-PLAN.md §3).
  :iban, :bank_account, :bank_swift, :bank_name, :bic, :swift,
  :vat, :vat_number, :registration_number, :reg_number,
  :client_name, :company_name
]
