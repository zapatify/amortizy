# Amortizy

[![Gem Version](https://img.shields.io/gem/v/amortizy.svg?style=flat)](https://rubygems.org/gems/amortizy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Ruby gem for generating loan amortization schedules. Supports monthly, bi-weekly, weekly, and daily payment frequencies with grace periods, interest-only payments, federal bank holidays, and multiple interest calculation methods.

Perfect for financial applications, lending platforms, and loan calculators.

## Features

- **Multiple payment frequencies**: Monthly, bi-weekly, weekly, or daily payments
- **Flexible loan terms**: Any term length in months, or specify an exact payment count
- **Dual input model**: Provide `term_months` (gem calculates payment count) or `num_payments` (you specify exactly how many)
- **Interest calculation methods**: Simple (accrued daily) or precomputed (fixed per payment)
- **Grace periods**: Grace periods before first payment (interest accrues and capitalizes)
- **Interest-only periods**: Configure initial interest-only payment phases
- **Fee handling**: Origination fees and additional fees with three treatment options
- **Bank day calculations**: Automatically skip weekends and US Federal Reserve holidays
- **Multiple output formats**: Console display or CSV export
- **Public API**: Programmatic access to schedule data, summaries, and totals
- **Commercial financing disclosures**: APR (Reg Z actuarial method), finance charge, amount financed, and more
- **Testing**: 120 RSpec tests

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'amortizy'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install amortizy
```

## Quick Start

### Monthly Loan (most common)

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 100_000.00,
  term_months: 12,
  annual_rate: 10.0,
  frequency: :monthly
)

# Display in console
schedule.generate

# Access data programmatically
schedule.summary          # => { start_date:, end_date:, principal:, total_payments:, ... }
schedule.payment_amount   # => 8791.59
schedule.total_interest   # => 5499.06
schedule.total_paid       # => 105499.06
schedule.end_date         # => #<Date: 2027-01-15>

# Get the full schedule as an array of hashes
schedule.schedule.each do |payment|
  puts "#{payment[:date]} - $#{'%.2f' % payment[:total_payment]}"
end

# Generate CSV file
schedule.generate(output: :csv, csv_path: "schedule.csv")
```

### Specify Exact Payment Count

Instead of a term length, tell the gem exactly how many payments you want:

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 50_000.00,
  num_payments: 26,
  annual_rate: 12.0,
  frequency: :biweekly
)

schedule.schedule.length    # => 26
schedule.end_date           # => the date of the 26th payment
schedule.term_months        # => nil (not applicable when using num_payments)
```

### Advanced Example with All Features

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 100_000.00,
  term_months: 12,
  annual_rate: 17.75,
  frequency: :monthly,
  origination_fee: 10_000.00,
  additional_fee: 2_500.00,
  additional_fee_label: "Processing Fee",
  additional_fee_treatment: :distributed,
  bank_days_only: true,
  interest_only_periods: 3,
  grace_period_days: 3,
  interest_method: :simple
)

schedule.generate
```

## API Reference

### Initialization Parameters

| Parameter | Type | Required | Default | Options | Description |
|-----------|------|----------|---------|---------|-------------|
| `start_date` | String/Date | Yes | - | YYYY-MM-DD | Loan start date |
| `principal` | Float | Yes | - | > 0 | Loan principal amount |
| `term_months` | Integer | One of* | - | Any positive integer | Loan term in months |
| `num_payments` | Integer | One of* | - | Any positive integer | Exact number of payments |
| `annual_rate` | Float | Yes | - | - | Annual interest rate (%) |
| `frequency` | Symbol | Yes | - | `:monthly`, `:biweekly`, `:weekly`, `:daily` | Payment frequency |
| `origination_fee` | Float | No | 0 | - | Fee added to principal |
| `additional_fee` | Float | No | 0 | - | Additional processing fee |
| `additional_fee_label` | String | No | "Additional Fee" | - | Label for additional fee |
| `additional_fee_treatment` | Symbol | No | `:distributed` | `:distributed`, `:add_to_principal`, `:separate_payment` | How to handle additional fee |
| `bank_days_only` | Boolean | No | false | - | Skip weekends and holidays |
| `interest_only_periods` | Integer | No | 0 | - | Number of interest-only payments |
| `grace_period_days` | Integer | No | 0 | - | Days before first payment |
| `interest_method` | Symbol | No | `:simple` | `:simple`, `:precomputed` | Interest calculation method |

*Provide either `term_months` or `num_payments`, not both.

### Public Methods

#### `#generate(output: :console, csv_path: nil)`

Render the schedule to console or CSV file.

```ruby
schedule.generate                                          # console output
schedule.generate(output: :csv, csv_path: "schedule.csv")  # CSV file
```

#### `#schedule`

Returns a frozen array of payment hashes. Each hash contains:

```ruby
{
  payment_number: 1,
  date: #<Date>,
  principal_payment: 8302.48,
  interest_payment: 489.11,
  additional_fee_payment: 0.0,
  total_payment: 8791.59,
  principal_balance: 91697.52,
  accrued_interest: 489.11,
  total_balance: 92186.63,
  payment_type: "Regular Payment",
  days_in_period: 29
}
```

#### `#summary`

Returns a hash with loan totals:

```ruby
{
  start_date: #<Date>,
  end_date: #<Date>,
  principal: 100000.0,
  total_payments: 12,
  frequency: :monthly,
  annual_rate: 10.0,
  payment_amount: 8791.59,
  total_interest: 5499.06,
  total_paid: 105499.06
}
```

#### Convenience Methods

| Method | Returns |
|--------|---------|
| `#end_date` | Date of the last payment |
| `#total_interest` | Sum of all interest payments |
| `#total_paid` | Sum of all payments |
| `#payment_amount` | Regular payment amount |

## Payment Frequencies

### Monthly (`:monthly`)

Payments on the same day each month. If the start date is the 31st, payments on shorter months use the last day of the month (e.g., Jan 31 -> Feb 28 -> Mar 28).

### Bi-weekly (`:biweekly`)

Payments every 14 days. Common for payroll-aligned loan repayment.

### Weekly (`:weekly`)

Payments every 7 days.

### Daily (`:daily`)

Payments every day. When combined with `bank_days_only: true`, payments skip weekends and federal holidays.

## Fee Treatment Options

### 1. Distributed (`:distributed`)
The fee is spread evenly across all payments.

**Best for:** Keeping individual payments manageable while recovering fees over time

### 2. Add to Principal (`:add_to_principal`)
The fee is added to the loan principal upfront, increasing the base amount financed.

**Best for:** Rolling all costs into the loan amount

### 3. Separate Payment (`:separate_payment`)
The fee is collected as a separate first payment before regular amortization begins.

**Best for:** Collecting fees upfront separately from the loan repayment

## Interest Calculation Methods

### Simple Interest (`:simple`)

Interest accrues daily on the remaining principal balance. As you pay down the principal, interest payments decrease over time.

**Formula:** Daily interest = (Principal Balance x Annual Rate) / 365

**Best for:** Traditional amortizing loans, consumer loans

### Precomputed Interest (`:precomputed`)

Total interest is calculated upfront based on the original principal and divided equally across all payments. Interest per payment stays constant regardless of principal reduction.

**Best for:** Fixed payment structures, certain consumer loan types

## Federal Bank Holidays

When `bank_days_only: true`, the schedule automatically skips weekends and US Federal Reserve holidays:

- New Year's Day, MLK Jr. Day, Presidents' Day, Memorial Day, Juneteenth, Independence Day, Labor Day, Columbus Day, Veterans Day, Thanksgiving, Christmas

Weekend observation rules are handled automatically by the `holidays` gem.

## Usage Examples

### 30-Year Mortgage

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 350_000.00,
  term_months: 360,
  annual_rate: 6.5,
  frequency: :monthly
)

puts "Monthly payment: $#{'%.2f' % schedule.payment_amount}"
puts "Total interest: $#{'%.2f' % schedule.total_interest}"
```

### Weekly Loan with Grace Period

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 75_000.00,
  term_months: 12,
  annual_rate: 15.0,
  frequency: :weekly,
  grace_period_days: 7
)

schedule.generate
```

### Interest-Only with Bank Days

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 100_000.00,
  term_months: 18,
  annual_rate: 10.0,
  frequency: :weekly,
  interest_only_periods: 8,
  bank_days_only: true
)

schedule.generate
```

### Complex Commercial Loan

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 250_000.00,
  term_months: 18,
  annual_rate: 14.5,
  frequency: :daily,
  origination_fee: 25_000.00,
  additional_fee: 5_000.00,
  additional_fee_label: "Processing Fee",
  additional_fee_treatment: :distributed,
  bank_days_only: true,
  interest_only_periods: 20,
  grace_period_days: 5,
  interest_method: :simple
)

schedule.generate(output: :csv, csv_path: "commercial_loan.csv")
```

## Commercial Financing Disclosures

Amortizy includes a disclosure module for computing data elements required by California SB 1235 and similar state commercial financing disclosure laws (New York, Georgia, etc.). Values are jurisdiction-agnostic — computed per the most stringent methodology, usable for any state.

The `Disclosure` class wraps an existing `AmortizationSchedule` and computes nine disclosure elements. The gem computes the numbers — your application handles document formatting.

**Key assumption:** The origination fee is treated as a prepaid finance charge (deducted from amount financed, included in finance charge). This is the standard treatment for commercial lending.

### Basic Usage

```ruby
schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2026-01-15",
  principal: 50_000,
  annual_rate: 12.0,
  frequency: :monthly,
  term_months: 36,
  origination_fee: 500,
  additional_fee: 250,
  additional_fee_treatment: :distributed
)

disclosure = Amortizy::Disclosure.new(schedule)

disclosure.apr                   # => 12.3 (Reg Z actuarial method, 10 bps precision)
disclosure.finance_charge        # => 11119.65
disclosure.amount_financed       # => 49500.0
disclosure.total_payment_amount  # => 60619.65
disclosure.recipient_funds       # => 49500.0
disclosure.term_display          # => "3 years, 0.20 months"
disclosure.average_monthly_cost  # => nil (monthly frequency)
disclosure.prepayment            # => { has_non_interest_charges: false, ... }
```

### With Third-Party Payments and Prepayment Info

```ruby
disclosure = Amortizy::Disclosure.new(
  schedule,
  third_party_payments: 10_000,
  prepayment_penalty_max: 1_200,
  additional_prepayment_fees: [
    { amount: 250.0, description: "Early termination fee" }
  ]
)

disclosure.recipient_funds  # => 39500.0 (amount_financed - third_party_payments)
disclosure.prepayment
# => {
#   has_non_interest_charges: true,
#   max_non_interest_finance_charge: 1200.0,
#   has_additional_fees: true,
#   additional_fees: [{ amount: 250.0, description: "Early termination fee" }]
# }
```

### Output Formats

```ruby
# Raw values
disclosure.to_h
# => { amount_financed: 49500.0, apr: 12.3, finance_charge: 11119.65, ... }

# With regulation-correct labels (per CA SB 1235 section 910)
disclosure.to_labeled_h
# => {
#   amount_financed: { label: "Funding Provided", value: 49500.0 },
#   apr: { label: "Annual Percentage Rate (APR)", value: 12.3 },
#   finance_charge: { label: "Finance Charge", value: 11119.65 },
#   ...
# }
```

### Disclosure Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `third_party_payments` | Float | 0 | Amounts paid to third parties from the financing |
| `prepayment_penalty_max` | Float | 0 | Maximum non-interest charge on early payoff |
| `additional_prepayment_fees` | Array | [] | Array of `{ amount:, description: }` hashes |

### Disclosure Elements

| Element | Method | Description | Regulatory Reference |
|---------|--------|-------------|---------------------|
| Funding Provided | `#amount_financed` | Principal adjusted for prepaid finance charges | §900(a)(1)(B) |
| APR | `#apr` | Annual percentage rate (Reg Z actuarial method) | §940 |
| Finance Charge | `#finance_charge` | Total dollar cost (derived from Reg Z identity) | §943 |
| Total Payment Amount | `#total_payment_amount` | Sum of all borrower payments | §910(a)(5) |
| Payment | `#payment_amount` | Regular periodic payment | §910(a)(6) |
| Term | `#term_display` | Days (<=1yr) or years/months (>1yr) | §901(a)(4) |
| Average Monthly Cost | `#average_monthly_cost` | For non-monthly frequencies only | §910(a)(12) |
| Recipient Funds | `#recipient_funds` | Net amount to borrower | §900(a)(26) |
| Prepayment | `#prepayment` | Prepayment penalty details | §910(a)(8-10) |

### Technical Notes

- **APR calculation** uses the actuarial method per Appendix J of Regulation Z (12 CFR Part 1026). Newton-Raphson solver with bisection fallback. APR rounded to nearest 10 basis points per §901(a)(5). Accuracy within 1/8 of 1 percentage point per §955.
- **Finance charge** is derived from the Reg Z identity: `total_payment_amount - amount_financed`. This guarantees the three core disclosure values are always internally consistent.
- **Floating-point arithmetic** is used for all calculations. This is adequate for typical commercial loans. For extremely large principals or very long terms (1000+ payments), consider validating against a reference APR calculator.

## Command Line Interface

Amortizy includes an interactive CLI tool:

```bash
amortizy
```

The CLI provides:
1. Run default examples (demonstrates simple vs precomputed interest)
2. Enter parameters manually with interactive prompts
3. Automatic CSV generation option

## Requirements

- Ruby 3.0 or higher
- `holidays` gem (~> 8.0) - automatically installed as a dependency

## Development

After checking out the repo, run:

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Run interactive console
bin/console
```

## Testing

The test suite includes 120 RSpec examples covering:

- Initialization and validation
- Payment calculations for all four frequencies
- Dual input model (term_months vs num_payments)
- Effective principal calculations
- Schedule generation and full amortization
- Interest methods (simple vs precomputed)
- Grace periods and interest-only periods
- Bank day functionality and federal holiday detection
- Fee treatments (distributed, add to principal, separate payment)
- Monthly date drift prevention with bank_days_only
- CSV generation
- Public API (schedule, summary, convenience methods)
- Deep freeze immutability
- Edge cases (year boundaries, month-end clamping, input validation)
- Commercial financing disclosures (APR, finance charge, amount financed, all nine elements)
- Reg Z identity verification across all fee treatment modes
- APR solver convergence (grace periods, interest-only, short-term, zero-rate loans)

Run the test suite:

```bash
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zapatify/amortizy.

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`bundle exec rspec`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to your branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Author

**Rich Zapata** - [@zapatify](https://github.com/zapatify)
