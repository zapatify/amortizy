# Amortizy v2.0 — Dynamic Payment Model

## Goal

Replace the hardcoded term/payment lookup table with a dynamic calculation engine.
Support two entry points: `term_months` (calculate payment count) or `num_payments`
(calculate end date). Add monthly and bi-weekly frequencies.

---

## Phase 1: Dynamic Payment Engine

### 1.1 Dual input model
- [ ] Accept `term_months` OR `num_payments` — one required, not both
- [ ] Validate: raise `ArgumentError` if both provided, or neither
- [ ] When `term_months` given: calculate `num_payments` from frequency
  - monthly: `term_months`
  - bi-weekly: `term_months * 2` (approx 26/year)
  - weekly: `term_months * 52 / 12` (rounded)
  - daily: calculate actual business/calendar days in the term
- [ ] When `num_payments` given: calculate end date by walking the payment schedule forward
- [ ] Remove the hardcoded `calculate_total_payments` lookup table
- [ ] Remove `validate_term_months!` (any positive integer is now valid)

### 1.2 New frequencies
- [ ] Add `:monthly` frequency — payment on same day each month (or last business day)
- [ ] Add `:biweekly` frequency — every 14 days
- [ ] Update `validate_frequency!` to accept all four
- [ ] Handle month-end edge cases for monthly (e.g., start Jan 31 — Feb payment is Feb 28)

### 1.3 Dynamic day calculation
- [ ] Replace static payment counts with actual date walking
- [ ] For daily + `bank_days_only`: count actual business days in the term
- [ ] For weekly/biweekly: walk forward by 7/14 days, skip to next bank day if needed
- [ ] For monthly: advance by calendar month, adjust for bank days

## Phase 2: Public API Cleanup

### 2.1 Expose schedule data
- [ ] Make `generate_schedule_data` public, rename to `schedule` or `to_a`
- [ ] Return frozen array of payment hashes
- [ ] Add `summary` method — returns hash with totals, dates, payment count
- [ ] Remove `send(:generate_schedule_data)` from README examples

### 2.2 Convenience methods
- [ ] `#end_date` — last payment date
- [ ] `#total_interest` — sum of all interest payments
- [ ] `#total_paid` — sum of all payments
- [ ] `#payment_amount` — make public (currently private)

## Phase 3: Extract Formatters

- [ ] Extract `ConsoleFormatter` — takes schedule data, renders table
- [ ] Extract `CsvFormatter` — takes schedule data, writes CSV
- [ ] `generate(output:)` delegates to formatter
- [ ] Engine class focuses on math only

## Phase 4: Polish

- [ ] Fix README broken markdown in Development section
- [ ] Update README examples for new API
- [ ] Update gemspec description
- [ ] Add CHANGELOG entry for v2.0
- [ ] Bump version
- [ ] Update Ruby requirement to >= 3.0
- [ ] Run full spec suite, update/add specs for new features

---

## Breaking changes (v2.0)

- `term_months` no longer restricted to [6, 9, 12, 15, 18]
- `generate_schedule_data` renamed to public method
- New frequencies may change default behavior for existing users (unlikely — additive)
