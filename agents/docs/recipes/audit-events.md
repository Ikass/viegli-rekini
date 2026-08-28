# Recipe: Audit events for sensitive operations

**When to reach for this:** any operation where you'd later need to answer "who did this, and
when" for a Latvian tax authority (VID) inquiry or a client dispute — invoice status
transitions, invoice edits after sending, account/user role changes, deletions. Not for routine
reads or ordinary CRUD on drafts.

This is deliberately smaller than a full-blown audit-log gem: one table, one concern, called
explicitly from services — not a Rails callback that fires invisibly on every save.

## Migration

```ruby
class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false          # "invoice.sent", "invoice.voided", "invoice.payment_recorded"
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.json :metadata, null: false, default: {}  # e.g. { from_status: "draft", to_status: "sent" }
      t.timestamps
    end
    add_index :audit_events, [:auditable_type, :auditable_id]
  end
end
```

SQLite supports `json` columns fine via Rails 8's serialization; no Postgres-specific `jsonb`
needed here.

## Model

```ruby
# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :auditable, polymorphic: true
end
```

## Recording from a service

Don't hook this into `after_save` — an implicit callback makes it easy to record the wrong
`metadata` or miss context that only the service knows. Record it explicitly, in the same
transaction as the state change:

```ruby
class InvoiceSender
  Result = Struct.new(:success, :invoice, keyword_init: true)

  def send_invoice(invoice:, by:)
    return Result.new(success: false, invoice: invoice) unless invoice.draft?

    ActiveRecord::Base.transaction do
      invoice.update!(status: :sent)
      AuditEvent.create!(
        account: invoice.account,
        user: by,
        action: "invoice.sent",
        auditable: invoice,
        metadata: { from_status: "draft", to_status: "sent" }
      )
    end

    Result.new(success: true, invoice: invoice)
  end
end
```

Apply the same shape to `InvoicePaymentRecorder` and `InvoiceVoider` — each transition service
gets one `AuditEvent.create!` call inside its transaction, with `from_status`/`to_status` (or
whatever's relevant) in `metadata`.

## Displaying it

A simple `Invoice#audit_events` (via `has_many :audit_events, as: :auditable`) plus a small
"History" card section on the invoice show view — same card-section pattern already used
elsewhere — is enough for v1. No need for a dedicated audit-log UI yet.

## What this buys you

- A real answer if VID or a client ever asks "who marked this paid, and when."
- Interview material: this is exactly the kind of "why does this exist" architectural decision
  your build log's `Decision:` field is meant to capture — link the log entry to this recipe when
  you implement it.
