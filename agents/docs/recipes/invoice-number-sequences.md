# Invoice number sequences (recipe)

> **Status:** decided direction, not yet built. Reach for this the next time invoice
> numbering is touched (multi-location, ecommerce store, or a concurrency bug report).

## Why this exists

`Invoice#generate_invoice_number` (`app/models/invoice.rb`) derives the next number by
`pluck`-ing every invoice number for the account, taking the `max_by` a digit-run regex, and
incrementing — all inside `account.with_lock`. Three problems:

1. **Race.** `with_lock` locks the *Account row*, not the numbering. SQLite has no row-level
   locks and serializes writes at the DB level, not reads, so two concurrent creates can both
   read the same max and both insert the same number. The second commit hits the unique index on
   `[account_id, invoice_number]` → `SQLite3::ConstraintException` → an unhandled 500 and a lost
   invoice. The lock gives a false sense of safety and wouldn't hold across multiple processes
   anyway (Puma workers, Solid Queue jobs).
2. **O(n) and fragile.** It plucks and sorts *every* number on each create, and `n[/\d+/].to_i`
   takes the *first* digit run — wrong if a prefix contains digits (e.g. `"2024"`).
3. **Single sequence per account.** It keys on `account_id` only, but an account will need
   **several** independent numbering sequences.

## The decision

A dedicated **sequence/counter table** with an atomic increment, keyed by
`(account_id, scope)`. `scope` is a string distinguishing sequences:

- `"default"` — the account's main sequence (today's behaviour).
- `"location:<id>"` — one per physical location (Phase 1B multi-location).
- `"ecommerce"` — a separate store sequence.

An account may therefore hold any number of sequences, each advancing independently.

## Data model sketch

```ruby
# db/migrate/xxx_create_invoice_sequences.rb
create_table :invoice_sequences do |t|
  t.references :account, null: false, foreign_key: true, index: false
  t.string     :scope,   null: false
  t.integer    :next_number, null: false, default: 1
  t.string     :prefix,  null: false            # e.g. "INV", or a location-specific prefix
  t.integer    :padding, null: false, default: 4
  t.timestamps
end

add_index :invoice_sequences, [ :account_id, :scope ], unique: true
```

`prefix`/`padding` move off `Account` (or stay there as defaults and are overridable per sequence)
so each location / ecommerce store can have its own formatting.

## Atomic allocation

The increment is a single statement SQLite serializes atomically — no lock needed, no race, no
O(n) scan:

```ruby
# InvoiceSequence
def self.next_for!(account, scope)
  row = connection.select_one(<<~SQL, "Next invoice number", [[nil, account.id], [nil, scope]])
    INSERT INTO invoice_sequences (account_id, scope, next_number, prefix, padding, created_at, updated_at)
    VALUES (?, ?, 2, #{quote(default_prefix)}, #{quote(default_padding)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (account_id, scope) DO UPDATE SET next_number = next_number + 1
    RETURNING next_number, prefix, padding
  SQL
  ...
end
```

Then format `"#{prefix}-#{next_number.to_s.rjust(padding, '0')}"`. The `INSERT … ON CONFLICT …
UPDATE` bump is idempotent and safe under concurrency (SQLite serializes the write; `RETURNING`
hands back the value this statement won).

## Migration / backfill

Seed one `default` sequence per existing account from its current max invoice number, so the
switchover doesn't reset numbering. `generate_invoice_number` then reads the sequence instead of
`pluck`-ing.

## When this becomes relevant

- Building multi-location support (invoices gain `location_id`; `scope` derives from it).
- Adding an ecommerce store sequence.
- Any report of duplicate invoice numbers or a `RecordNotUnique` 500.

Until then, the current `max_by` approach is acceptable for single-server SQLite with low write
concurrency — this recipe exists so the eventual replacement follows one documented shape rather
than a fresh invention.
