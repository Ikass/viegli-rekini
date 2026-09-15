# Contract: Tenancy scoping

This is the one pattern every new resource must follow. If you're adding a model, controller, or
job and you're not sure how it should be scoped — this is the answer, not a judgment call.

## The rule

Every tenant-owned table has an explicit `account_id` column with `null: false,
foreign_key: true, index: true` — except `LineItem`, which is scoped through its parent
`invoice.account` (no denormalised `account_id` yet; see the Phase 1B note below). There is no
`default_scope` on the tenancy boundary. Every lookup traverses `Current.user.account` (or
`Current.user.account.locations.find(...)` for location-owned data, once locations exist)
explicitly.

```ruby
# Good — the tenancy boundary is visible in the line itself
@invoice = Current.user.account.invoices.find_by!(id: params[:id])

# Bad — never do this. Even if a before_action checked account_id elsewhere,
# this line reads as unscoped to anyone auditing it later, human or agent.
@invoice = Invoice.find(params[:id])
```

Always `find_by!`, never `find_by` — a silently-nil tenant lookup is a bug, not a 404 to handle
gracefully later.

## Foreign keys in params

A foreign key submitted by the client (`invoice[client_id]`, a future `location_id`, etc.) is **not**
proof that the referenced record belongs to the current account. Resolve it through the account on
the way in:

```ruby
# Good — resolve the FK through the account, never trust the raw id
@invoice = Current.user.account.invoices.build(invoice_params)
@invoice.client = Current.user.account.clients.find(params[:invoice][:client_id])

# or validate at the model boundary
#   validate :client_belongs_to_account
#   def client_belongs_to_account
#     errors.add(:client, "must belong to your account") if client && client.account_id != account_id
#   end
```

A `collection_select` scoped to `Current.user.account.clients` in the view only constrains the
`<option>` list — a crafted request can submit any `client_id`. `InvoicesController` resolves the
client through the account (`resolve_client`), and `Invoice` also validates
`client_belongs_to_account` as defense in depth. The negative cross-tenant test (checklist item 5)
is what keeps this from regressing.

## Location-level scoping

> **Phase 1B — not built yet.** `Location`/`LocationMembership` are planned but don't exist. When
> they land, some resources (invoices) will belong to a `Location`, itself scoped under an
> `Account`. Scope through the narrowest tenant that applies:

```ruby
@invoice = Current.account.locations
                          .find(params[:location_id])
                          .invoices
                          .find_by!(id: params[:id])
```

If a `LocationMembership` restricts which users can operate at that location, check it after the
lookup, not instead of it — the tenancy scope and the permission check are two different
questions.

## Background jobs

> **Phase 1B — not built yet.** There are no background jobs today. When they appear, they won't
> have a request-scoped `Current`. Serialize the account explicitly (GlobalID) and restore it at
> the top of `perform`:

```ruby
class InvoiceReminderJob < ApplicationJob
  def perform(account:, invoice_id:)
    Current.account = account
    invoice = Current.account.invoices.find_by!(id: invoice_id)
    # ...
  end
end
```

Never pass a bare `invoice_id` and re-derive the account from the invoice — that inverts the
scoping direction and makes it possible to enqueue a job for the wrong tenant by mistake.

## New resource checklist

When adding a new tenant-owned model:

1. Migration: `account_id` with `null: false, foreign_key: true, index: true` — or, for a nested
   resource owned through a parent (like `LineItem` under `Invoice`), rely on the parent's
   `account_id` and scope through it.
2. Model: `belongs_to :account`, no `default_scope` on the tenancy boundary.
3. Controller: every lookup goes through `Current.user.account...find_by!`.
4. If the resource is created via a background job, serialize the account and restore it at the
   top of `perform` (Phase 1B — no jobs exist yet).
5. Test: write one test that a user from Account A cannot read/write a record belonging to
   Account B via this controller — this is the test that actually catches a broken tenancy
   boundary, not a happy-path CRUD test.
