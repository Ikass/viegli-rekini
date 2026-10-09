# frozen_string_literal: true

namespace :demo do
  desc "Reset the demo tenant to the seeded state (destroys and re-seeds)"
  task reset: :environment do
    user = DemoAccount.user

    if user
      # Destroying the account cascades to users, sessions, clients, products,
      # and invoices — a clean slate for db:seed to repopulate.
      user.account.destroy!
    end

    Rake::Task["db:seed"].invoke
    puts "Demo tenant reset. Sign in with #{DemoAccount::EMAIL} / #{DemoAccount::PASSWORD}."
  end
end
