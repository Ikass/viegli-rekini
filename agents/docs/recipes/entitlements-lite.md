# Recipe: Entitlements/Limits, sized for "no billing yet"

**When to reach for this:** the moment you decide on a pricing model (you're currently weighing
per-invoice pricing vs. a free/paid split) and need product code to ask "can this account do X"
without that question turning into scattered `if account.plan == "pro"` checks across
controllers.

This is the idea behind Rails Baseline's `Entitlements.enabled?` / `Limits.value` split, resized
for an app with no Stripe integration yet. The point of adopting the *shape* now, even before you
add real billing, is that product code never has to change when billing does — only the thing
underneath these two methods changes.

## The split

- **Entitlements** — a yes/no capability question. "Can this account export invoices as XML?"
- **Limits** — a quantity question. "How many locations may this account create?"

Product code only ever asks these two questions. It never inspects `account.plan` directly, and
it never will need to when Stripe eventually sits underneath.

## Minimal implementation (no billing model yet)

```ruby
# frozen_string_literal: true

# app/models/account.rb — for now, plan lives as a plain enum column on Account.
# When real billing arrives, only this file and PlanRules change — nothing that
# calls Entitlements or Limits needs to.
class Account < ApplicationRecord
  enum :plan, { free: 0, paid: 1 }, default: :free
end
```

```ruby
# frozen_string_literal: true

module PlanRules
  ENTITLEMENTS = {
    free: %i[].freeze,
    paid: %i[xml_export bulk_send].freeze
  }.freeze

  LIMITS = {
    free: { locations: 1, invoices_per_month: 20 },
    paid: { locations: 5, invoices_per_month: Float::INFINITY }
  }.freeze
end
```

```ruby
# frozen_string_literal: true

module Entitlements
  def self.enabled?(account:, key:)
    PlanRules::ENTITLEMENTS.fetch(account.plan.to_sym, []).include?(key)
  end
end
```

```ruby
# frozen_string_literal: true

module Limits
  def self.value(account:, key:)
    PlanRules::LIMITS.fetch(account.plan.to_sym).fetch(key)
  end
end
```

## Using it

```ruby
# Controller — boolean capability
def export
  unless Entitlements.enabled?(account: Current.user.account, key: :xml_export)
    redirect_to invoices_path, alert: "XML export is a paid feature."
    return
  end
  # ...
end

# Model or service — quantity
def location_limit_reached?
  locations.count >= Limits.value(account: self, key: :locations)
end
```

## What changes later, when billing becomes real

When you add Stripe/Pay, `Account#plan` stops being a plain column you set by hand and becomes
derived from subscription state. `Entitlements` and `Limits` keep the exact same public
interface — only their internals start reading from the billing boundary instead of
`account.plan`. Nothing that calls `Entitlements.enabled?` or `Limits.value` today needs to
change. That's the whole value of adopting the split now rather than after you have paying
customers and a pile of `account.plan == "pro"` checks to hunt down.

## What NOT to build yet

- No Stripe/Pay gem until there's an actual pricing decision made and a customer ready to pay.
- No admin UI for plan management — a Rails console `account.update!(plan: :paid)` is fine for
  the first handful of manual upgrades.
- No usage-based billing — flat plan tiers are enough until per-invoice pricing is actually
  decided and modeled.
