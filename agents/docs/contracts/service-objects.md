# Contract: Service objects

Referenced from `ARCHITECTURE.md`'s decision table under "is this a status transition?" — this is
the one shape every service object follows.

## The rule

One public method per service, explicitly named (never a generic `call`). Returns a `Result`
struct. Callers check `result.success?` — never infer success from the model's state afterward,
since that couples the caller to implementation details the service should own.

```ruby
class InvoiceSender
  Result = Struct.new(:success, :invoice, :error, keyword_init: true)

  def send_invoice(invoice:)
    return Result.new(success: false, invoice: invoice, error: "Not a draft.") unless invoice.draft?
    invoice.update!(status: :sent)
    Result.new(success: true, invoice: invoice)
  end
end
```

```ruby
# Controller — checks the Result, doesn't re-derive success from invoice.status
result = InvoiceSender.new.send_invoice(invoice: @invoice)
if result.success?
  redirect_to result.invoice, notice: "Invoice sent."
else
  redirect_to result.invoice, alert: "Invoice could not be sent."
end
```

## When a transition needs an audit trail

If the operation is one that needs a record of who/when (see `agents/docs/recipes/audit-events.md`),
the `AuditEvent.create!` call goes inside the same transaction as the state change, inside the
service — not bolted on afterward in the controller:

```ruby
def send_invoice(invoice:, by:)
  return Result.new(success: false, invoice: invoice) unless invoice.draft?

  ActiveRecord::Base.transaction do
    invoice.update!(status: :sent)
    AuditEvent.create!(account: invoice.account, user: by, action: "invoice.sent",
                        auditable: invoice, metadata: { from_status: "draft", to_status: "sent" })
  end

  Result.new(success: true, invoice: invoice)
end
```

## New service checklist

1. One public method, named for what it does (`send_invoice`, not `call` or `execute`).
2. `Result = Struct.new(:success, :invoice, :error, keyword_init: true)` — swap `:invoice` for
   whatever the relevant record is; `:error` is an optional string for surfacing a reason on
   failure.
3. Guard the precondition first, return an unsuccessful `Result` immediately if it fails.
4. Wrap the state change (and any `AuditEvent`) in a transaction.
5. Controller checks `result.success?` only — no follow-up queries to confirm state.
