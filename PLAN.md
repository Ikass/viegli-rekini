# viegli-rēķini.lv — Implementation Plan

> Last updated: July 2026
> Next: Phase 1B — Multi-Tenancy & Company Architecture  
> Status: v0.1 MVP complete (clients, products, invoices, print view)

---

## 1. What This App Is

**viegli-rēķini.lv** is a simple invoicing SaaS for Latvian small businesses and sole traders. The goal is to make it trivially easy to create, send, and track invoices that are fully compliant with Latvian law — including the incoming structured e-invoice (e-rēķins) mandate.

The target user is a solo operator or micro-business that wants to issue compliant invoices without the overhead of a full accounting suite.

**Tech stack:** Rails 8, SQLite3, Hotwire (Turbo + Stimulus), vanilla CSS, Kamal 2 on OVH (live), Litestream → Cloudflare R2 backups (planned), MailerSend for email (planned).

---

## 2. Regulatory Background

### 2.1 Primary legal sources

| Document                                  | URL                                                        | Relevance                                                            |
| ----------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------- |
| Grāmatvedības likums (Law on Bookkeeping) | https://likumi.lv/ta/id/324249                             | Defines invoice mandatory fields, structured e-invoice obligation    |
| MK Nr. 154 (2019) — E-invoice standard    | https://likumi.lv/doc.php?id=306273                        | Mandates PEPPOL BIS Billing 3.0 / UBL 2.1 as the applicable standard |
| MK Nr. 749 (2025) — E-invoice circulation | https://likumi.lv/ta/id/365040                             | Defines delivery channels, VID submission rules, deadlines           |
| VID e-rēķini info page                    | https://www.vid.gov.lv/lv/e-rekini                         | VID's guidance, service provider list, XML samples                   |
| PEPPOL BIS Billing 3.0 spec               | https://docs.peppol.eu/poacc/billing/3.0/                  | The actual XML specification to implement                            |
| Finanšu ministrija — e-rēķini             | https://www.fm.gov.lv/lv/strukturets-elektroniskais-rekins | FM Q&A and implementation guidance                                   |
| VDAA e-rēķini (XML samples)               | https://www.vdaa.gov.lv/lv/e-rekini                        | XML schema samples, validation info                                  |

### 2.2 Mandatory invoice fields (Grāmatvedības likums, 11. pants)

Every invoice issued to another business must contain:

- Document type name (e.g. "Rēķins")
- Document date (`issued_at`)
- Document number (`invoice_number`)
- **Seller:** company name/firm, registration number or tax payer code
- **Buyer:** same identifying information (reg number / taxpayer code); for private individuals — name and surname
- Transaction description and value in EUR
- Quantity and unit of measure (where applicable)
- Signature or equivalent (for electronic: an electronic confirmation)

### 2.3 The structured e-invoice mandate — timeline

| Date       | Obligation                                                                          |
| ---------- | ----------------------------------------------------------------------------------- |
| 2025-01-01 | Invoices to **budget institutions** (valsts iestādes) must be structured e-invoices |
| 2026-01-01 | B2B voluntary e-invoice submission to VID opens (via EDS API or e-adrese)           |
| 2028-01-01 | **All B2B invoices** between Latvian companies must be structured e-invoices        |

The 2028 deadline was pushed back from the original 2026 date by Saeima amendments in June 2025.

### 2.4 Required format

- **XML standard:** UBL 2.1
- **Profile:** PEPPOL BIS Billing 3.0 CIUS (Core Invoice Usage Specification)
- **EN standard:** LVS EN 16931-1:2017 (semantic data model) + LVS CEN/TS 16931-2:2017 (syntax list)
- **Document type code:** 380 = commercial invoice; 381 = credit note

This is not a PDF. A human-readable PDF is a companion to the XML, not a substitute for it in B2B contexts.

### 2.5 Delivery channels (MK Nr. 749, §4–5)

Companies **agree with each other** which channel(s) to use. Three options:

1. **e-adrese** — Latvia's official electronic address system (free, run by the state). Available from 2026-01-01 for e-invoice circulation.
2. **Operator/PEPPOL service provider** — commercial e-invoice operators integrated with VID's API. VID maintains a list at: https://www.vid.gov.lv/lv/e-rekini
3. **Other channel** — system-to-system integration, email with XML attachment, or any agreed electronic method.

### 2.6 VID submission rules (MK Nr. 749, §10–17)

After sending an invoice to the buyer, the **issuer must also submit it to VID**:

- **Deadline:** within **5 business days** of the sent date (§14)
- **VID submission channels:**
  - Via **e-adrese** — automatically forwarded to VID (§11)
  - Via **operator API** integrated with VID's API (§10.2)
  - Via **VID EDS API** or manual XML upload in EDS (§10.3)
- VID stores the XML **without attachments** — no PDF, no linked documents (§7)
- **Late submission due to system failure:** notify VID via EDS the next business day; submit within 3 business days of fix (§15)
- **Late submission for other reasons:** notify VID via EDS; submit within 30 calendar days of identifying the failure (§17)
- B2B voluntary VID submission via EDS/operator opens **2026-01-01** (§18)

---

## 3. Current State (v0.1 MVP)

The following is already built:

- **Account + User** — registration creates an Account (company profile with address, bank details, VAT info, registration number) and a User (login credentials) in a single transaction. Rails 8 session-based auth.
- **Clients** — CRUD for invoice recipients (name, company name, email, address, city, postal code, country, VAT number)
- **Products** — reusable line item templates (name, description, default price in cents, default VAT rate)
- **Invoices** — create invoice with nested line items via Stimulus form controller, pick from products or enter manually, auto-calculate subtotal + VAT + total in Ruby (integer cents, VAT rounded once per category)
- **Status transitions** — dedicated service objects for each transition (InvoiceSender, InvoicePaymentRecorder, InvoiceVoider), exposed as REST resources (not custom member actions)
- **Account settings** — company details, address, bank info (bank name, IBAN, SWIFT) on a single edit/update page
- **Print view** — browser-printable invoice layout showing seller/buyer addresses, line items, totals, bank details, and notes
- **Product picker** — Stimulus controller that auto-fills line item fields (description, unit price, VAT rate) from a product selection dropdown
- **Seed file** — demo account with sample clients, products, and invoices across all statuses
- **bin/ci** — full CI pipeline: setup → rubocop → bundler-audit → importmap audit → brakeman → tests → seed replant → system tests
- **System tests** — invoice lifecycle and client CRUD via `data-testid` selectors

---

## 4. Data Model

### 4.1 Current model (what exists)

```
Account (tenant)
  - name: string, not null
  - company_name: string
  - registration_number: string
  - vat_number: string
  - address, city, postal_code, country: string
  - bank_name, bank_account, bank_swift: string

User
  - email_address: string, not null, unique
  - password_digest: string, not null
  - account_id: references Account, not null

Client
  - account_id: references Account, not null
  - name: string, not null
  - company_name: string
  - email: string
  - vat_number: string
  - address, city, postal_code, country: string

Product
  - account_id: references Account, not null
  - name: string, not null
  - description: text
  - default_price_cents: integer, not null (euro cents — 5000 = €50.00)
  - default_vat_rate: decimal, not null

Invoice
  - account_id: references Account, not null
  - client_id: references Client, not null
  - invoice_number: string, not null, unique per account
  - issued_on: date, not null
  - due_on: date, not null
  - status: enum (draft: 0, sent: 1, paid: 2, void: 3), not null, default: draft
  - notes: text

LineItem
  - invoice_id: references Invoice, not null
  - description: string, not null
  - quantity: decimal, not null
  - unit_price_cents: integer, not null (euro cents)
  - vat_rate: decimal, not null, default: 0
  - position: integer (for ordering)
```

**Calculated on Invoice (no DB columns):**

- `subtotal` — sum of line item subtotals
- `vat_total` — VAT rounded once per category (EN 16931 BR-CO-17), summed across categories
- `total` — subtotal + vat_total

**Status lifecycle:**

```
draft → sent → paid
  ↓       ↓      ↓
void    void   void
```

### 4.2 Fields to add (required for compliance and e-invoice XML)

#### On `accounts` (seller details — already exist since Phase 1):

```ruby
# Already in schema. Listed here as the ground truth for UBL XML generation:
# Bank details (for PEPPOL PaymentMeans element)
#   accounts.bank_name      :string
#   accounts.bank_account   :string   # IBAN
#   accounts.bank_swift      :string

# Invoice defaults
#   accounts.invoice_prefix          :string, default: "INV"
#   accounts.invoice_number_padding  :integer, default: 4
#   Number sequence derived from existing invoices per account, not a stored counter

# PEPPOL (future — when registering as PEPPOL participant)
# add_column :accounts, :peppol_id, :string
```

**Note:** In previous versions of this document these fields were incorrectly listed under `users`. They are company-level, not user-level, and already exist on the `accounts` table as of Phase 1.


#### On `clients` (buyer details):

```ruby
# Required for e-invoice buyer identification
add_column :clients, :iban, :string           # buyer's bank (for payment references)
add_column :clients, :country_code, :string, default: "LV"  # ISO 3166-1 alpha-2

# E-invoice delivery preference
add_column :clients, :delivery_channel, :string, default: "email"
  # "email" | "e_adrese" | "operator" | "other"
add_column :clients, :e_adrese_id, :string    # buyer's e-adrese identifier (if known)
add_column :clients, :is_budget_institution, :boolean, default: false
  # Budget institutions need e-invoices from 2025-01-01
```

#### On `invoices`:

```ruby
# E-invoice status tracking
add_column :invoices, :sent_at, :datetime
add_column :invoices, :vid_submit_status, :string, default: "pending"
  # "not_required" | "pending" | "submitted" | "failed" | "late_reported"
add_column :invoices, :vid_submitted_at, :datetime
add_column :invoices, :vid_submit_error, :text
add_column :invoices, :vid_submit_deadline, :date  # sent_at + 5 business days

# E-invoice XML
add_column :invoices, :xml_generated_at, :datetime
add_column :invoices, :ubl_xml, :text  # stored XML for audit trail

# PEPPOL fields
add_column :invoices, :document_type_code, :string, default: "380"
  # 380 = invoice, 381 = credit note
add_column :invoices, :buyer_reference, :string  # BT-10, often buyer's PO number

# Notes / additional info
add_column :invoices, :notes, :text
add_column :invoices, :currency_code, :string, default: "EUR"
```

#### On `line_items`:

```ruby
# Required for UBL XML
add_column :line_items, :unit_code, :string, default: "C62"
  # UN/ECE unit codes: C62=pieces, HUR=hours, DAY=days, MON=months,
  # KGM=kilograms, MTR=metres — see full list: https://docs.peppol.eu/poacc/billing/3.0/codelist/UNECERec20/
add_column :line_items, :tax_category_code, :string, default: "S"
  # "S" = standard rate, "Z" = zero-rated, "E" = exempt,
  # "AE" = reverse charge (VAT payer→VAT payer, services)
```

---

## 5. Implementation Phases

---

### Phase 1 — Foundation & Compliance Hardening

*Goal: Invoices are legally complete and generate valid UBL 2.1 XML. Users can download and manually submit to VID.*

#### 1.1 Seller profile completion

- Add IBAN, bank name, payment terms, invoice number settings to user profile
- Validate that required seller fields are present before allowing invoice creation
- Invoice number auto-generation with configurable prefix and sequential counter

#### 1.2 Mandatory field validation

Enforce all Grāmatvedības likums 11. pants required fields:

- Seller: company name, registration number (or taxpayer code)
- Buyer: name, registration number (or taxpayer code); for private individuals — name/surname only
- Invoice: type name, date, number, line item descriptions, amounts

Show clear UI errors if any are missing before the invoice can be finalised.

#### 1.3 Client model enhancements

- Add `country_code`, `is_budget_institution`, `delivery_channel` fields
- In client form: flag whether the client is a budget institution (triggers immediate e-invoice obligation)
- Add `iban` and `e_adrese_id` fields (optional, for future delivery automation)

#### 1.4 Line item unit codes

- Add `unit_code` (UN/ECE) and `tax_category_code` to line items
- Provide a sensible default picker in the UI (Pieces, Hours, Days, Months, kg, m)
- VAT category: standard (S), zero-rated (Z), exempt (E), reverse charge (AE)

#### 1.5 UBL 2.1 XML generation

This is the core technical deliverable of Phase 1. Generate a valid PEPPOL BIS Billing 3.0 XML file for each invoice.

**Key UBL elements to implement:**

```xml
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2">

  <cbc:UBLVersionID>2.1</cbc:UBLVersionID>
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>
  <cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>
  <cbc:ID><!-- invoice_number --></cbc:ID>
  <cbc:IssueDate><!-- issued_at --></cbc:IssueDate>
  <cbc:DueDate><!-- due_at --></cbc:DueDate>
  <cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>  <!-- or 381 for credit note -->
  <cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>
  <cbc:BuyerReference><!-- buyer_reference --></cbc:BuyerReference>

  <!-- AccountingSupplierParty (seller) -->
  <!-- AccountingCustomerParty (buyer) -->
  <!-- PaymentMeans (IBAN, payment reference) -->
  <!-- PaymentTerms -->
  <!-- TaxTotal (VAT breakdown by category) -->
  <!-- LegalMonetaryTotal (subtotals, total) -->
  <!-- InvoiceLine (one per line item) -->
</Invoice>
```

**Implementation approach:**

Use Rails ERB templates to render XML (no separate gem needed for simple UBL):

```
app/views/invoices/
  _ubl.xml.erb    # full UBL XML template
```

Or use a dedicated service object:

```ruby
# app/services/ubl_invoice_builder.rb
class UblInvoiceBuilder
  def initialize(invoice)
    @invoice = invoice
  end

  def build
    # returns XML string
  end
end
```

Store the generated XML in `invoices.ubl_xml` at the time of sending for audit trail. If the invoice is edited, regenerate before resending.

**Validation:** Run the generated XML against the PEPPOL BIS Billing 3.0 schematron rules. The VDAA provides XML schema samples at https://www.vdaa.gov.lv/lv/e-rekini. Consider using `nokogiri` for XML building and schema validation.

#### 1.6 PDF generation

Generate a professional PDF companion to the XML. Options:

- **Prawn** gem — programmatic PDF generation, full control
- **WickedPdf** (wkhtmltopdf) — render existing HTML print view to PDF
- **Grover** (headless Chrome) — most faithful to CSS, recommended if the print view already looks good

The PDF is sent to the buyer; it is NOT submitted to VID.

#### 1.7 Invoice download page

On the invoice show page:

- Download XML button → serves `invoice_XXXX.xml` with correct MIME type (`application/xml`)
- Download PDF button → serves `invoice_XXXX.pdf`
- Print button → existing browser print view

#### 1.8 Status update: `sent`

Add a "Mark as Sent" action that:

- Sets `invoice.sent_at = Time.current`
- Sets `invoice.status = :sent`
- Calculates and stores `vid_submit_deadline` (sent_at + 5 business days, skipping weekends and Latvian public holidays)
- Sets `vid_submit_status = "pending"`
- Queues the VID submission job (Phase 2)

**Deliverables at end of Phase 1:**

- All invoices have legally required fields
- Valid UBL 2.1 XML generated and downloadable
- PDF generated and downloadable
- User can manually upload XML to VID EDS at https://eds.vid.gov.lv

---

### Phase 2 — VID Submission (EDS API)

*Goal: App automatically submits e-invoices to VID within the 5-business-day deadline.*

#### 2.1 VID EDS API integration

VID's Electronic Declaration System provides an API for programmatic submission. Implement:

```ruby
# app/services/vid_submission_service.rb
class VidSubmissionService
  VID_EDS_API_BASE = "https://eds.vid.gov.lv/api/..."  # confirm current endpoint

  def initialize(invoice)
    @invoice = invoice
  end

  def submit
    # POST invoice.ubl_xml to VID EDS API
    # Handle response: success → update vid_submit_status, vid_submitted_at
    #                  failure → log error, update vid_submit_status = :failed
  end
end
```

Check VID's EDS API documentation at https://www.vid.gov.lv/lv/eds-api-servisa-apraksts for current endpoint and authentication method.

#### 2.2 Submission state machine

```
not_required     # B2C invoices, or before 2026 for B2B (voluntary period)
pending          # sent_at set, awaiting submission
submitted        # successfully submitted to VID
failed           # submission attempted, error received
late_reported    # past deadline, notified VID via EDS
```

#### 2.3 Background job (Solid Queue)

```ruby
# app/jobs/vid_submission_job.rb
class VidSubmissionJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 1.hour, attempts: 5

  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    return if invoice.vid_submit_status == "submitted"

    result = VidSubmissionService.new(invoice).submit

    if result.success?
      invoice.update!(
        vid_submit_status: "submitted",
        vid_submitted_at: Time.current
      )
    else
      invoice.update!(
        vid_submit_status: "failed",
        vid_submit_error: result.error_message
      )
      # Re-raise to trigger Solid Queue retry
      raise result.error_message
    end
  end
end
```

#### 2.4 Deadline monitoring job

```ruby
# app/jobs/vid_deadline_monitor_job.rb
# Run daily via Solid Queue recurring schedule
class VidDeadlineMonitorJob < ApplicationJob
  def perform
    # Find invoices past deadline that haven't been submitted
    overdue = Invoice.where(
      vid_submit_status: ["pending", "failed"],
      vid_submit_deadline: ...Date.today
    )

    overdue.each do |invoice|
      # Notify admin by email
      # Attempt late submission
      # Update status to late_reported if submission still failing
    end
  end
end
```

#### 2.5 Late submission notification (MK Nr. 749, §17)

If submission fails past the 5-business-day deadline, the law requires:

1. Notify VID via EDS stating the reason and period (§17.1)
2. Submit within 30 calendar days (§17.2)

Implement a UI flow and/or automated notification to handle this.

#### 2.6 Admin dashboard: VID submission status

Add a section to the dashboard showing:

- Invoices pending VID submission
- Invoices approaching deadline (< 2 business days remaining)
- Invoices past deadline (red alert)
- Successfully submitted count (this month)

**Deliverables at end of Phase 2:**

- Invoices automatically submitted to VID within 5 business days
- Failed submissions retried with Solid Queue
- Dashboard shows submission health

---

### Phase 3 — Email Delivery

*Goal: Send invoice to buyer by email, with XML + PDF attached.*

#### 3.1 InvoiceMailer

```ruby
# app/mailers/invoice_mailer.rb
class InvoiceMailer < ApplicationMailer
  def send_invoice(invoice)
    @invoice = invoice
    @sender = invoice.user

    # Attach both files
    attachments["rekini_#{invoice.invoice_number}.xml"] = {
      mime_type: "application/xml",
      content: invoice.ubl_xml
    }
    attachments["rekini_#{invoice.invoice_number}.pdf"] = {
      mime_type: "application/pdf",
      content: invoice.generate_pdf
    }

    mail(
      to: invoice.client.email,
      from: @sender.email,
      reply_to: @sender.email,
      subject: "Rēķins #{invoice.invoice_number} — #{@sender.company_name}"
    )
  end
end
```

#### 3.2 Send invoice flow

On "Send Invoice" action:

1. Generate/regenerate XML
2. Generate PDF
3. Queue `InvoiceMailer.send_invoice(invoice).deliver_later`
4. Set `sent_at`, `status: :sent`, calculate `vid_submit_deadline`
5. Queue `VidSubmissionJob`
6. Show confirmation flash

#### 3.3 Email templates (bilingual LV/EN)

Invoice email body should contain:

- Greeting and invoice summary
- Key amounts (subtotal, VAT, total, due date)
- Payment instructions (IBAN, reference)
- Note about attached XML + PDF

**Deliverables at end of Phase 3:**

- One-click "Send Invoice" from the invoice show page
- Buyer receives email with both XML and PDF
- VID submission triggered automatically

---

### Phase 4 — Invoice Lifecycle Management

*Goal: Reminders, overdue tracking, credit notes, dashboard.*

#### 4.1 Payment status tracking

- Mark invoice as **Paid** (stores `paid_at`)
- Overdue detection: job runs daily, marks sent invoices past `due_at` as overdue
- Invoice aging report: how long invoices have been outstanding

#### 4.2 Payment reminder emails

```ruby
# Triggered by daily Solid Queue job
class PaymentReminderJob < ApplicationJob
  def perform
    # 3-day reminder: due in 3 days, not yet paid
    # Overdue reminder: 1 day past due, 7 days past due, 14 days past due
  end
end
```

Configurable per user: enable/disable automatic reminders, customise timing.

#### 4.3 Credit notes (document type 381)

- "Issue credit note" action on a paid/sent invoice
- Creates a new invoice with `document_type_code: "381"`, negated amounts
- Links back to original invoice (`credit_note_for_invoice_id`)
- Same XML + PDF generation + VID submission flow

#### 4.4 Dashboard

- Outstanding invoices (sent but unpaid)
- Overdue invoices (highlighted)
- Revenue this month / quarter / year
- VID submission health
- Quick action: create invoice, view overdue

---

### Phase 5 — e-adrese Channel

*Goal: Support delivery via Latvia's official electronic address system (available from 2026-01-01).*

#### 5.1 e-adrese integration

The e-adrese system is operated by VDAA (Valsts drošības aģentūra). When used as the delivery channel:

- VID automatically receives the e-invoice — no separate VID submission needed (§11)
- The e-adrese system handles automatic forwarding to VID

Integration resources:

- VDAA e-adrese info: https://www.vdaa.gov.lv/lv/e-rekini
- Latvija.gov.lv e-invoice portal: https://latvija.gov.lv

#### 5.2 Per-client delivery channel

In the send invoice flow, check `client.delivery_channel`:

- `email` → Phase 3 mailer flow + manual VID submission (Phase 2)
- `e_adrese` → send via e-adrese API + automatic VID submission
- `operator` → send via operator's API + automatic VID submission

---

### Phase 6 — PEPPOL Operator Integration (Pre-2028)

*Goal: Full PEPPOL network participation for seamless cross-company e-invoice exchange.*

Either:

**Option A — Partner with an existing operator:**
Connect to a Latvian PEPPOL service provider. VID maintains the current list at https://www.vid.gov.lv/lv/e-rekini. The operator handles routing, VID submission, and PEPPOL network connectivity. Your app integrates via the operator's API.

**Option B — Become a registered operator:**
Register with VID as an e-invoice service provider. Requires direct API integration with VID's system (§10.2) and integration with the PEPPOL network. Significantly more complex but positions the app as infrastructure rather than just a client.

**Recommended:** Start with Option A (partner) and evaluate Option B once user volume justifies it.

---

### Phase 7 — Deploy & Polish

*Goal: Live on production, ready for paying users.*

#### 7.1 Deployment

```bash
# OVH VPS (deployed; see agents/docs/notes/kamal-ovh-deploy.md)
kamal setup
kamal deploy

# Ongoing
kamal app logs -f
kamal app exec --interactive bin/rails console
kamal app exec bin/rails db:migrate
```

#### 7.2 Litestream backups

```yaml
# config/litestream.yml
dbs:
  - path: /app/db/production.sqlite3
    replicas:
      - type: s3
        bucket: viegli-rekini-backups
        path: db
        endpoint: https://ACCOUNT.r2.cloudflarestorage.com
        force-path-style: true
```

#### 7.3 Multi-tenancy hardening

Every database query must be scoped to `current_user`. Add a `before_action` in `ApplicationController`:

```ruby
def current_user_scope
  raise "Missing user scope" unless current_user
end
```

Add model-level scopes and validate that all associations belong to the current user before any write operation.

#### 7.4 Subscription billing (future)

Stripe or LemonSqueezy for subscription management. Not in scope until the app has validated users.

---

## 6. Key Technical Decisions

### XML generation: ERB templates vs builder gem

**Decision: ERB templates** in `app/views/invoices/ubl.xml.erb`

Rationale: UBL XML has a fixed, well-known structure. ERB templates are readable, version-controllable, and don't require an additional dependency. A `UblInvoiceBuilder` service object wraps the render call and handles validation.

### PDF generation

**Decision: Evaluate Grover (headless Chrome) first**

Rationale: The print view already exists and looks correct. Grover renders it faithfully. If Grover proves too heavy for the server, fall back to Prawn (more work but no external dependency).

### VID submission: EDS API vs manual upload

**Decision: EDS API (§10.3) for Phase 2; evaluate operator for Phase 6**

Rationale: EDS API doesn't require operator registration and is the simplest path to automated submission. The manual upload path (user downloads XML and uploads to EDS) is the Phase 1 fallback.

### Business days calculation

The 5-business-day VID submission deadline requires skipping weekends and Latvian public holidays. Use the `business_time` gem or implement a simple custom calculator with a hardcoded Latvian public holiday list (updated annually).

### Invoice number format

Configurable prefix + sequential counter per account (per location in Phase 1B). Examples: `2026-001`, `INV-0042`, `RIGA-2026-001`. Counter from a per-account `invoice_sequences` table, bumped atomically (`INSERT … ON CONFLICT … RETURNING`); the number is assigned at send.

### Multi-tenancy: Identity/User split

**What:** `Identity` (global email+password, one per human) + `User` (per-company role join). A person signs in as an Identity; which Company they're acting within determines which User record is active. Adopted from Fizzy.

**Why:** A Latvian accountant managing multiple clients needs one login for multiple companies. The current schema stores `email_address` with a global unique constraint directly on `User` — the same human cannot belong to two accounts.

**Pros:** One credential set per person. Clean role-per-company. No duplicated email/password. The Fizzy cascading setter pattern (`Current.session=` → `Current.identity=` → `Current.user=` scoped to `Current.account`) makes resolution near-invisible at the controller level.

**Cons:** Adds one join hop to every `Current.user` resolution. Existing registration flow needs rewriting (creates Identity + Account + User in one transaction). Password reset needs to find Identity by email, not User.

### Tenant resolution: URL path prefix vs session-only

**What:** Tenant (Company) is identified by a numeric ID in the URL path (`/42/invoices/5`). A Rack middleware extracts the slug, rewrites `SCRIPT_NAME`, and sets `Current.account`. Adopted from Fizzy's `AccountSlug::Extractor`.

**Why:** Deep-linking is critical for invoicing — users share invoice links with colleagues and clients. Session-only tenancy (`Current.account = current_user.selected_account`) breaks on direct links and prevents multi-tab use (different companies in different tabs share one session).

**Pros:** URLs carry their own context — bookmarkable, shareable, multi-tab-safe. Middleware is ~30 lines. No DNS wildcard or SSL complexity (unlike subdomain approach). Rails' `SCRIPT_NAME` rewrite makes all URL helpers work automatically.

**Cons:** Every route needs the tenant prefix. Turbo Streams and ActionCable need explicit `script_name` awareness (Fizzy has proven patterns for both). Registration/login pages need `disallow_account_scope` to reject tenant-prefixed URLs.

### Company invite flow: join code vs email invitation

**What:** Each Company has a generated join code (e.g. `aB3d-9Xy2-wQ7k-Lm5n`). The admin shares this code; new users visit `/join/:join_code`, verify it against `Current.account.join_code`, and register. Adopted from Campfire and Writebook.

**Why:** Email-based invitation requires a working mailer before anyone can join a second company — a bootstrap problem. Manual user creation by admin doesn't scale past 2–3 users.

**Pros:** Shareable via any channel (email, Slack, WhatsApp — the admin chooses). No mailer dependency. `before_create` generates the code automatically. Admin can regenerate to revoke access. Pattern is 15 lines of concern + one controller action.

**Cons:** No per-invitation tracking (who used the code, when). No expiry (though regeneration = revocation). Not suitable for bulk invitations with role pre-selection — if needed later, extend to `CompanyInvitation` model with email + role.

### Multi-location: membership join vs simple location_id

**What:** `LocationMembership` join table (`user_id`, `location_id`, `role`) scopes which users can create/view invoices for which locations. Admin/accountant roles bypass the check entirely (`User#accessible_locations` returns all company locations). Adopted from Campfire's Room/Membership pattern.

**Why:** A bare `location_id` drop-down on the invoice form lets every user create invoices for any location — fails for franchise/retail scenarios where a cashier shouldn't see another store's invoices. Separate Accounts per location work under the tenancy model but make cross-location reporting painful.

**Pros:** Clean access boundaries. Admin override via role check, not membership check. Three-column table — negligible schema overhead. Checked once per request in `before_action`, not on every query. Per-location invoice numbering (prefix + counter) naturally follows.

**Cons:** UI for managing memberships (admin assigns operators to locations). Initial setup: creating a location should auto-grant the creator operator access. Slightly more schema than bare `location_id`.

### Authentication concern: require_account and disallow_account_scope

**What:** Two class-level methods on the `Authentication` concern. `require_account` is a `before_action` that redirects to a session-selection menu if `Current.account` is nil. `disallow_account_scope` (used on signup/login pages) redirects away if a tenant slug IS present in the URL. Adopted from Fizzy.

**Why:** After introducing URL-path tenancy, pages have implicit expectations about whether a tenant context should exist. A bookmarked invoice URL without an active session hits a page it can't render. A login page at `/42/session/new` is confusing — which company are you logging into?

**Pros:** Formalises tenant-context requirements as an explicit concern rather than implicit assumptions. Both methods are ~5 lines. `disallow_account_scope` prevents the confusing "half-scoped" state on auth pages.

**Cons:** Adds a before_action to every request. But the check is `Current.account.present?` — negligible overhead.

### Per-company JSON settings (Campfire's `has_json` pattern)

**What:** Optional per-company preferences stored as a JSON column on `Account` (`settings`), using `ActiveRecord::Base.store_accessor` for typed getters/setters with defaults. Not individual schema columns. Adopted from Campfire's `has_json :settings` on Account.

**Why:** Avoids column proliferation for optional preferences: default VAT rate, default payment terms in days, default currency, notification toggles (email on send, email on overdue), invoice template selection. Each new option would otherwise require a migration.

**Pros:** New preferences require no migration — just add a default to `store_accessor`. Settings are read once per request into `Current.account`. Typed accessors (`settings[:default_vat_rate]` returns Float, not String).

**Cons:** JSON columns cannot be indexed or queried via SQL efficiently. Not suitable for data you need to `WHERE` on (that belongs in real columns). Schema-less by definition — no DB-level type enforcement for nested values.

### Webhook system for external integrations

**What:** Two custom models — `Webhook` (per-company URL + HMAC secret) and `WebhookDelivery` (request/response log per delivery). Domain events (invoice.created, invoice.sent, invoice.paid, invoice.voided) fire registered webhooks via a background job. Adopted from Fizzy. No third-party gem.

**Why:** Webhooks are the integration surface for external accounting software, Zapier, and custom client dashboards. A gem adds abstraction for a pattern that is fundamentally two tables + one HTTP POST.

**Pros:** ~100 lines of owned code. Two models, one job, one service — fully debuggable. Follows existing service-object conventions. Company-scoped (each Company manages its own webhooks).

**Cons:** No automatic retry beyond Solid Queue's native retries out of the box. No webhook signature verification out of the box (add HMAC verification to `Webhook` model when needed). No webhook event type filtering initially — all events fire to all registered URLs.

### SQLite FTS5 full-text search (no Elasticsearch/Meilisearch)

**What:** SQLite's built-in FTS5 virtual tables for full-text search across invoices, clients, and products. No external search service. Adopted from Campfire (`message_search_index`) and Fizzy (sharded `search_records_*`).

**Why:** As soon as a company has 50+ invoices, searching by client name, invoice number, or line item description becomes necessary. FTS5 is built into SQLite — zero additional infrastructure — and handles prefix queries, phrase matching, and relevance ranking.

**Pros:** Zero infrastructure. Single-table approach (Campfire's model) is sufficient for viegli-rekini's scale — Fizzy's sharding is overkill until millions of records. No separate service to maintain, monitor, or pay for.

**Cons:** FTS5 doesn't support Latvian stemming out of the box. Acceptable for structured data (invoice numbers, client names, product codes) — less relevant for free-text notes. Triggers need to be maintained to keep the FTS index in sync with source tables.

### Cross-device session transfer (QR code login)

**What:** A logged-in user can generate a transfer token (Rails `signed_id`, 4-hour expiry) displayed as a QR code. Scanning it on another device authenticates that device without re-entering credentials. Adopted from Campfire and Writebook's `User::Transferable` concern.

**Why:** Business users switch devices — an accountant starts on desktop, needs to show something on their phone during a client meeting. Re-entering credentials on mobile is friction. The pattern is ~20 lines and purely additive.

**Pros:** High perceived polish for a business app. ~20 lines of implementation — a model concern + one controller action. Uses Rails' built-in `signed_id` (no new dependency). Route reserved early avoids renumbering later.

**Cons:** 4-hour expiry window means the QR code on a long-idle screen may be stale. No revocation mechanism (acceptable for a convenience feature, not a security control). Requires `rqrcode` gem (already in Writebook's Gemfile as a reference).

### SaaS engine separation (Fizzy's `saas/` directory)

**What:** Billing, subscription, provisioning, and storage-limit logic lives in a `saas/` directory loaded only when `ENV["SAAS"]=true`. The core invoicing app has no knowledge of billing beyond checking `Account.active?`. Adopted from Fizzy.

**Why:** When Stripe/LemonSqueezy subscriptions are added in Phase 8, billing code should not leak into invoice logic. The separation makes the app testable without billing dependencies and makes changing billing providers a single-directory swap.

**Pros:** Clean boundary between core domain and billing infrastructure. Tests for invoicing don't need Stripe mocks. Switching billing providers means replacing one directory, not hunting through models. Fizzy has proven this in production.

**Cons:** Adds an engine loading conditional in `config/application.rb`. The `Account.active?` flag is the only shared interface — needs to be maintained as the contract between billing and core.

### Rate limiting: built-in `rate_limit` vs rack-attack

**What:** Use Rails 8's built-in `rate_limit` controller macro (`rate_limit to: 10, within: 3.minutes`) for login attempts and API endpoints. Not the `rack-attack` gem. Observed in all three Basecamp reference apps.

**Why:** The built-in `rate_limit` covers the core use cases — login attempts, magic link requests, API endpoint throttling — without an additional dependency. `rack-attack` adds IP-based blocks and Redis-backed counters but is premature for a small SaaS.

**Pros:** No additional dependency. Single-line declaration per action. Works with Rails' existing cache store (Solid Cache). Covers per-action throttling which is sufficient through Phase 5+.

**Cons:** Less granular than rack-attack — no IP-based rate limiting at the Rack level, no custom throttling rules based on request headers. If per-IP blocking becomes necessary (e.g., after a brute-force attack), rack-attack or Cloudflare is the upgrade path.

### No Devise, no acts_as_tenant — custom auth and tenancy as core domain

**What:** Stay on Rails' `has_secure_password` + custom `Authentication` concern for auth, and explicit `account_id` FKs with `Current.account` for tenancy. Do not introduce Devise or acts_as_tenant. Validated by all three Basecamp reference apps — none use either gem.

**Why for no Devise:** Password reset, session management, and registration are already working with `has_secure_password` + `Authentication` concern. Devise adds metaprogramming, a global initializer, and view-generation conventions that fight against custom UI. The current approach is 80 lines of concern + ~30 lines of views — known, owned, debuggable.

**Why for no acts_as_tenant:** acts_as_tenant uses `default_scope`-based row filtering — it silently hides rows from other tenants, which breaks when you forget to call `current_tenant=` and makes debugging cross-tenant leaks painful. Fizzy's explicit `account_id` on every table + association traversal is more predictable. Cross-tenant leak tests are straightforward: `assert_not_equal account_a.invoices, account_b.invoices`.

**Pros (custom auth):** No magic. Every line is yours. Debuggable without reading gem source. `has_secure_password` handles bcrypt correctly (Battle-tested Rails built-in). **Pros (custom tenancy):** No silent row filtering. No `default_scope` surprises. Explicit scoping makes security audits straightforward.

**Cons (custom auth):** You maintain password-reset mailer, rate limiting, and session expiry yourself — Devise handles these out of the box. **Cons (custom tenancy):** Every developer must remember to scope queries — `acts_as_tenant` does this automatically (for better and worse).

---

## 7. Important UN/ECE Unit Codes (for line items)

| Code | Meaning                   |
| ---- | ------------------------- |
| C62  | Pieces (gabali) — default |
| HUR  | Hours (stundas)           |
| DAY  | Days (dienas)             |
| MON  | Months (mēneši)           |
| KGM  | Kilograms                 |
| MTR  | Metres                    |
| LTR  | Litres                    |
| SET  | Sets / komplekti          |

Full list: https://docs.peppol.eu/poacc/billing/3.0/codelist/UNECERec20/

## 8. VAT Category Codes (for line items)

| Code | Meaning        | When to use                                           |
| ---- | -------------- | ----------------------------------------------------- |
| S    | Standard rate  | Normal VAT-registered B2B/B2C transactions            |
| Z    | Zero-rated     | Exports, certain goods                                |
| E    | Exempt         | VAT-exempt services                                   |
| AE   | Reverse charge | Services between VAT payers (PVN apgrieztā maksāšana) |
| O    | Outside scope  | Not subject to VAT                                    |

---

## 9. Useful References

- **PEPPOL BIS Billing 3.0 full spec:** https://docs.peppol.eu/poacc/billing/3.0/
- **UBL 2.1 Invoice schema:** http://docs.oasis-open.org/ubl/os-UBL-2.1/UBL-2.1.html
- **VDAA XML samples (Latvia):** https://www.vdaa.gov.lv/lv/e-rekini
- **VID EDS API docs:** https://www.vid.gov.lv/lv/eds-api-servisa-apraksts
- **VID e-rēķini page (service provider list, guidance):** https://www.vid.gov.lv/lv/e-rekini
- **Latvija.gov.lv e-invoice portal:** https://latvija.gov.lv
- **PVN likums (for VAT rules on invoices):** https://likumi.lv/ta/id/35734

---

## 10. Phase Summary

| Phase | Deliverable                                                                                                  | Status |
| ----- | ------------------------------------------------------------------------------------------------------------ | ------ |
| v0.1  | Account + User, clients, products, invoices with status transitions, print view, account settings, seed data | ✅ Done |
| 1     | Compliant fields, UBL XML, PDF, manual VID upload                                                            | ⬜ Next |
| 2     | VID EDS API auto-submission, deadline monitoring                                                             | ⬜      |
| 3     | Email delivery (XML + PDF attached)                                                                          | ⬜      |
| 4     | Reminders, credit notes, dashboard                                                                           | ⬜      |
| 5     | e-adrese delivery channel                                                                                    | ⬜      |
| 6     | PEPPOL operator integration                                                                                  | ⬜      |
| 7     | Deploy to OVH, Kamal, Litestream                                                                         | ⬜      |

---

## 11. Updating This Document

As decisions are made and phases completed:

- Mark phases ✅ in the summary table
- Add new decisions to Section 6 (Key Technical Decisions)
- Update the data model in Section 4 if schema changes
- Note any regulatory updates (the e-invoice space is still evolving)
