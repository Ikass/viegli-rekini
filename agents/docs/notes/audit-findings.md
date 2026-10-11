# Audit findings — the hard-won details

> Written 2026-10-09 during the deploy audit. These are the four issues that surfaced and the
> deeper "why" behind each, so the reasoning is recoverable later without re-deriving it.
> They back the decisions in `../DEPLOY-PLAN.md` and the wording in the CV.

---

## 1. SQLite has no row locks — `with_lock` / `lock!` is a no-op (but the "race" still doesn't fire)

> **As built (2026-10-11):** numbering moved to a dedicated `invoice_sequences` counter table with
> an atomic `INSERT … ON CONFLICT (account_id, scope) DO UPDATE … RETURNING` (see
> `recipes/invoice-number-sequences.md`). One catch worth knowing: `select_value`/`select_all`
> mis-handle an UPSERT's `RETURNING` and return the stale value without incrementing — use
> `exec_query`, not `select_value`.

### What the code does

`Invoice#generate_invoice_number` (a `before_validation :on => :create`) does:

```ruby
account.with_lock do
  last_number = account.invoices.pluck(:invoice_number).compact.max_by { |n| n[/\d+/].to_i }
  # … increment, pad, assign self.invoice_number
end
```

### What I assumed vs. what's true

I initially described this as a concurrency **race**: "the lock doesn't hold across the INSERT, so
two concurrent creates can both read the same max and hit `RecordNotUnique`." That's the classic
PostgreSQL/MySQL mental model, and it's what `recipes/invoice-number-sequences.md` says too. It is
**wrong for SQLite**. I verified against the installed Rails 8.1.3.1 source:

1. **`with_lock` = `transaction { lock!(true) { … } }`** — and `lock!(true)` reloads with
   `SELECT … FOR UPDATE`.
2. **The SQLite Arel visitor drops the `FOR UPDATE` clause.** In
   `arel/visitors/sqlite.rb`:

   ```ruby
   # Locks are not supported in SQLite
   def visit_Arel_Nodes_Lock(o, collector)
     collector
   end
   ```

   So `lock!`/`lock`/`with_lock`'s lock is a **literal no-op** on SQLite. No row lock is ever
   taken. (The user's instinct here was exactly right — I was wrong.)
3. **But `with_lock` also opens a transaction, and Rails' SQLite transactions are `BEGIN IMMEDIATE`,
   not `BEGIN DEFERRED`.** From `sqlite3/database_statements.rb`:

   ```ruby
   def begin_db_transaction
     internal_begin_transaction(:immediate, nil)
   end
   ```

   `BEGIN IMMEDIATE` takes SQLite's `RESERVED` lock — the *single writer* lock — at transaction
   start. Combined with the default `journal_mode = wal` + `synchronous = normal` + a busy-handler
   timeout, this means **concurrent write transactions serialize**: only one is active at a time.
4. **Because `generate_invoice_number` runs inside the invoice's own save transaction** (Rails wraps
   callbacks + INSERT in one `transaction`), the max-read happens *while holding the write lock*.
   The second concurrent create's `BEGIN IMMEDIATE` blocks until the first commits, then reads a
   max that already includes the first invoice.

### Net effect

The current code is **effectively race-free on SQLite today** — not because of any row lock, but
because SQLite serializes the entire write transaction at the file level. The safety is
**incidental**, not intentional.

### Why the counter table is still worth doing

The race not firing doesn't make the code good. The genuine defects remain:

- **O(n):** every create `pluck`s and sorts *every* invoice number for the account.
- **Digit-prefix bug:** `n[/\d+/].to_i` takes the *first* digit run, so a prefix like `INV24-` is
  misread as `24` → numbering breaks. This is the bug a regression test *can* actually catch.
- **Fragility:** correctness rests on `BEGIN IMMEDIATE` + the read happening inside the transaction.
  Change either (multi-process with a different journal mode, a `requires_new:` savepoint, moving
  the read out of the transaction) and the race becomes real again. A dedicated counter table makes
  the intent explicit and correct by construction.

### How to describe it honestly (CV)

> Sequential invoice numbers via a dedicated counter table using SQLite's atomic
> `INSERT…ON CONFLICT…RETURNING` inside the same transaction as the invoice — **not**
> `SELECT FOR UPDATE`, which SQLite does not support.

Say "robustness refactor", never "fixing a race".

---

## 2. EN 16931 VAT rounding is per *rate category*, not per line

> **As built (2026-10-11):** `Invoice#vat_breakdown` now rounds VAT once per category and
> `UblInvoiceBuilder` + `_document.html.erb` read from it; the SQL `SUM`/`ROUND` path is gone and
> `LineItem#subtotal` rounds half-up. The `MoneyAmount` VO remains deferred.

### What I got wrong

I initially said "line-level round-half-up, then sum" matches EN 16931. It does **not** — for VAT
the canonical rule rounds **once per VAT category/rate**. (The user's memory beat mine; I confirmed
against the official schematron.)

### The exact rules (from ConnectingEurope/eInvoicing-EN16931, mirrored in PEPPOL BIS 3.0)

- **BR-CO-17** (fatal): *"VAT category tax amount (BT-117) = VAT category taxable amount (BT-116) ×
  (VAT category rate (BT-119) / 100), rounded to two decimals."*
- **BR-CO-14** (fatal): *"Invoice total VAT amount (BT-110) = Σ VAT category tax amount (BT-117)."*
- **BR-CO-10** (fatal): *"Sum of Invoice line net amount = Σ Invoice line net amount."*

So:

```
category_taxable = Σ line_net                    # per rate group
category_tax     = round_half_up(category_taxable × rate / 100)   # rounded ONCE
total_vat        = Σ category_tax                # BR-CO-14
```

"Sum of per-line rounded VAT" (which is what `UblInvoiceBuilder` and `_document.html.erb` do today)
can drift a cent from `round(category_taxable × rate)`, which is exactly the off-by-0.01 that trips
BR-CO-14/BR-CO-17 in a validator.

### Which rule does Latvia allow?

Latvia mandates EN 16931 (MK Nr. 154/2019 → UBL 2.1 / PEPPOL). So **Latvian practice *is* the
EN 16931 per-category rule** — there is no separate LV rounding override. Per-category-round-once
is correct for both compliance and what the standard Latvian accounting packages do.

### Consequence for the code

`UblInvoiceBuilder#tax_groups` currently emits `TaxAmount = items.sum(&:vat_amount)` (sum of
per-line rounded VAT). It must become `round(items.sum(&:subtotal) × rate / 100)`. `_document.html.erb`
has the same bug, plus it groups by `vat_rate` only while the builder groups by `[category, rate]`
— a second divergence that has to go. `Invoice#vat_total` (SQL) is a third, float-backed path.

---

## 3. Gapless numbering means drafts must not consume numbers

> **As built (2026-10-11):** numbers are now assigned at send, not draft — `InvoiceSender` allocates
> via `InvoiceSequence.next_for!` inside the invoice's own transaction, and `invoice_number` is
> nullable with a conditional `presence` validation (`unless: :draft?`). Deleting a draft consumes
> nothing; the counter bump and the status flip commit/roll back together.

### The conflict

- Numbers are assigned in `before_validation :on => :create` → **every** invoice, including
  drafts, gets a number at creation.
- `InvoicesController#destroy` and the "Delete draft" button let drafts be deleted.

Deleting a draft therefore **burns a number**, producing a gap. Latvian accounting law requires
sequential numbering; a draft that's never issued is *not* an accounting source document and
shouldn't take a slot.

### The resolution (chosen)

**Number on issue, not on draft.** Drafts carry no `invoice_number` (nullable column + partial
unique index); `InvoiceSender#send_invoice` allocates the number via the counter table in the same
transaction that flips draft → sent. "Delete draft" stays, and deleting a draft consumes nothing.

### Why "same transaction" matters for "gapless"

The counter bump and the invoice INSERT must commit or roll back together. If the number were
allocated in a separate `transaction(requires_new: true)` (or a job), a failed insert after a
successful allocation would burn a number. Keeping the allocation inside the save/send transaction
means a rollback reverts the bump too — the increment is *not* idempotent-safe unless it shares the
transaction.

---

## 4. Solid Queue/Cache/Cable are "intended future", not active — and one leftover will crash Puma

### The deferred stack

`config/production.rb` runs `config.active_job.queue_adapter = :async` and
`config.cache_store = :memory_store` — in-process, non-durable. The Solid gems are commented out of
the `Gemfile`, so `bin/jobs`, `config/queue.yml`, `config/recurring.yml`, `config/cache.yml`, and
`db/{queue,cache,cable}_schema.rb` are intended-future config, not live.

### The concrete bug

`config/deploy.yml` sets `SOLID_QUEUE_IN_PUMA: true`, and `config/puma.rb` does:

```ruby
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
```

But `solid_queue` isn't in the bundle, so in production Puma would try to load a plugin that
doesn't exist and **fail to boot**. This is the single thing that hard-blocks a live deploy,
independent of all the other "boring config" work. Fix: remove the env line and/or the plugin line.

---

## 5. Money columns — where the float actually lives

> **As built (2026-10-11):** the SQL `SUM`/`ROUND` float path is gone — `Invoice` computes in Ruby
> over `LineItem` (BigDecimal/integer cents). Column types unchanged.

- Prices are **integer cents** (`unit_price_cents`, `default_price_cents`) — exact, no problem.
- `quantity` is `decimal(10,2)` and `vat_rate` is `decimal(5,2)`. SQLite has no true decimal type
  (NUMERIC affinity → 64-bit float), **but** ActiveRecord casts these columns to `BigDecimal` in
  Ruby, so **Ruby arithmetic on them is already exact**.
- The float problem exists **only** in SQL `SUM`/`ROUND` expressions over those columns (the two in
  `Invoice#subtotal`/`#vat_total`). That's why the fix is "stop doing money in SQL", not a schema
  migration — the column types are fine; the *computation location* is what must move.
