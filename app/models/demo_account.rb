# frozen_string_literal: true

# The shared, seeded demo tenant. Single source of truth for the demo
# credentials so seeds.rb, the "Try the demo" button, and the reset task
# don't drift.
module DemoAccount
  EMAIL = "demo@example.com"
  PASSWORD = "password"

  def self.user
    User.find_by(email_address: EMAIL)
  end
end
