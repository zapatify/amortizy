# Amortizy v2.1 — Commercial Financing Disclosure Module

## Goal

Add a `Disclosure` class that computes California SB 1235 disclosure data elements
for closed-end commercial loan transactions. The gem exposes jurisdiction-agnostic
numbers — APR (Reg Z actuarial method), finance charge, amount financed, recipient
funds, term, average monthly cost, and prepayment info — queryable via a clean API.

**Design decisions:**
- `Amortizy::Disclosure` is a separate class that wraps an `AmortizationSchedule`
- Origination fee is treated as a prepaid finance charge by default (deducted from
  amount financed, included in finance charge) — must be documented
- No state/jurisdiction parameters — data elements are universal
- No document formatting — the gem computes numbers, not PDFs
- Scoped to closed-end transactions only (no MCA, factoring, leases, open-end)

**Regulatory references:**
- Section 910: Closed-end transaction disclosure contents
- Section 940: APR calculation (Appendix J, 12 CFR Part 1026 — actuarial method)
- Section 943: Finance charge definition
- Section 900(a)(1)(B): Amount financed for closed-end transactions
- Section 900(a)(26): Recipient funds
- Section 955: APR tolerance (1/8 of 1 percentage point)

---

## Phase 1: Disclosure Class Skeleton

### 1.1 Create `lib/amortizy/disclosure.rb`
- [ ] Define `Amortizy::Disclosure` class
- [ ] Accept `AmortizationSchedule` as first argument
- [ ] Accept keyword args: `third_party_payments: 0`, `prepayment_penalty_max: 0`,
      `additional_prepayment_fees: []`
- [ ] Validate that schedule argument is an `AmortizationSchedule`
- [ ] Store schedule reference and disclosure-specific params

### 1.2 Wire into gem
- [ ] Add `require_relative 'amortizy/disclosure'` to `lib/amortizy.rb`
- [ ] Create `spec/disclosure_spec.rb` with basic instantiation tests

---

## Phase 2: Simple Computed Properties

These derive directly from existing schedule data with minimal new logic.

### 2.1 Finance Charge (§943)
- [ ] `#finance_charge` — total dollar cost of financing
- [ ] Calculation: `total_interest + origination_fee + additional_fee`
- [ ] All charges that would be included under 12 CFR 1026.4 if this were consumer credit
- [ ] Spec: verify against known loan (e.g., $50K, 12%, 36mo, $500 orig fee, $250 addl fee)

### 2.2 Amount Financed (§900(a)(1)(B))
- [ ] `#amount_financed` — principal + financed amounts - prepaid finance charges
- [ ] For closed-end: `principal + additional_fee (if add_to_principal) - origination_fee`
- [ ] Origination fee treated as prepaid finance charge (deducted)
- [ ] Additional fee treatment depends on `additional_fee_treatment` setting:
  - `:distributed` or `:separate_payment` → not added to amount financed
  - `:add_to_principal` → added to amount financed
- [ ] Spec: test all three fee treatment scenarios

### 2.3 Total Payment Amount (§910(a)(5))
- [ ] `#total_payment_amount` — delegates to `schedule.total_paid`
- [ ] Spec: verify matches schedule total

### 2.4 Recipient Funds (§900(a)(26))
- [ ] `#recipient_funds` — net amount given directly to the borrower
- [ ] Calculation: `amount_financed - third_party_payments`
- [ ] Spec: with and without third-party payments

### 2.5 Term Display (§901(a)(4))
- [ ] `#term_days` — total days from start to last payment
- [ ] `#term_display` — formatted per regulation:
  - Term <= 1 year: display in days (e.g., "270 days")
  - Term > 1 year: display in years and months, remainder as decimal
    (e.g., "2 years, 3.15 months")
- [ ] Spec: test boundary at exactly 365 days, and multi-year terms

### 2.6 Average Monthly Cost (§910(a)(12))
- [ ] `#average_monthly_cost` — total payments / (term_days / 30.4)
- [ ] Returns `nil` for monthly frequency (only required for non-monthly)
- [ ] Spec: weekly and biweekly loans, verify nil for monthly

---

## Phase 3: APR Calculation (§940)

The core engineering work. APR per Appendix J of Regulation Z (12 CFR Part 1026).

### 3.1 Actuarial method solver
- [ ] Implement APR calculation using the actuarial method
- [ ] The APR is the rate `i` that satisfies:
      `Amount Financed = Σ (Payment_k / (1 + i)^(t_k / 365))`
      where `t_k` is the number of days from disbursement to payment k
- [ ] Use Newton-Raphson iteration to solve for `i`
- [ ] Convergence tolerance: 1/8 of 1 percentage point (0.00125) per §955
- [ ] Maximum iterations: 100 (with fallback to bisection if Newton diverges)
- [ ] Cash flows: amount financed is the initial advance (positive);
      each scheduled payment is an outflow (negative)
- [ ] Include all finance charge components in the payment stream

### 3.2 Cash flow extraction
- [ ] Extract payment dates and amounts from the schedule
- [ ] Include separate_payment additional fees in the stream
- [ ] Include grace period payments if any
- [ ] Disbursement date = schedule start_date
- [ ] Each payment: { date:, amount: } from schedule rows

### 3.3 APR formatting
- [ ] `#apr` — returns APR as a percentage rounded to nearest 10 basis points (§901(a)(5))
      e.g., 14.8, 14.85, not 14.8532
- [ ] Spec: verify against known Reg Z examples
- [ ] Spec: tolerance check — result within 1/8 percentage point of exact

### 3.4 Edge cases
- [ ] Zero-interest loans (APR should reflect fees only)
- [ ] Loans with grace periods (disbursement date vs first payment date gap)
- [ ] Interest-only periods followed by amortizing payments
- [ ] Precomputed interest method
- [ ] Very short terms (< 30 days)
- [ ] Very long terms (> 10 years)

---

## Phase 4: Prepayment Information (§910(a)(8-10))

### 4.1 Prepayment hash
- [ ] `#prepayment` — returns hash:
      ```ruby
      {
        has_non_interest_charges: true/false,
        max_non_interest_finance_charge: Float or nil,
        has_additional_fees: true/false,
        additional_fees: [] # array of { amount:, description: } hashes
      }
      ```
- [ ] Derived from `prepayment_penalty_max` and `additional_prepayment_fees` inputs
- [ ] Spec: all four combinations (charges/no charges x fees/no fees)

---

## Phase 5: Output Methods

### 5.1 `#to_h`
- [ ] Returns flat hash of all computed values:
      ```ruby
      {
        amount_financed:, apr:, finance_charge:, total_payment_amount:,
        payment_amount:, payment_frequency:, term_days:, term_display:,
        average_monthly_cost:, recipient_funds:, prepayment:
      }
      ```
- [ ] All monetary values as Float, rounded to 2 decimal places
- [ ] Spec: verify all keys present, types correct

### 5.2 `#to_labeled_h`
- [ ] Returns hash with regulation-correct labels:
      ```ruby
      {
        amount_financed: { label: "Funding Provided", value: 50_250.00 },
        apr: { label: "Annual Percentage Rate (APR)", value: 14.85 },
        finance_charge: { label: "Finance Charge", value: 10_432.50 },
        ...
      }
      ```
- [ ] Labels follow §910 column 1 text for fixed-rate closed-end transactions
- [ ] Spec: verify exact label strings match regulation text

---

## Phase 6: Documentation & Polish

### 6.1 README updates
- [ ] Add Disclosure section to README with usage examples
- [ ] Document the origination fee = prepaid finance charge assumption
- [ ] Document regulatory references (CA SB 1235, sections 910/940/943)
- [ ] Note that labels follow California regulation but values are jurisdiction-agnostic

### 6.2 CHANGELOG
- [ ] Add v2.1.0 entry documenting the disclosure module

### 6.3 Version bump
- [ ] Bump version to 2.1.0 in `version.rb`

### 6.4 Final spec run
- [ ] Full suite green — existing specs unaffected
- [ ] Disclosure specs comprehensive — all nine data elements tested
- [ ] APR accuracy verified against at least 3 known Reg Z examples

---

## Out of Scope

- MCA / sales-based financing disclosures (§914)
- Factoring disclosures (§912, §913)
- Open-end credit plan disclosures (§911)
- Lease financing disclosures (§915)
- Asset-based lending disclosures (§916)
- Disclosure document generation (PDF/HTML formatting)
- Jurisdiction detection or state-specific logic
- Adjustable rate APR estimation (amortizy only does fixed-rate)
- Retrospective APR auditing (§931)
