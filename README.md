# Amortizy

[![Gem Version](https://badge.fury.io/rb/amortizy.svg)](https://rubygems.org/gems/amortizy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Ruby library for generating professional loan amortization schedules with advanced features including grace periods, interest-only payments, federal bank holidays, and multiple interest calculation methods.

Perfect for financial applications, lending platforms, and loan calculators.

## Features

- **Multiple payment frequencies**: Daily or weekly payments
- **Flexible loan terms**: 6, 9, 12, 15, or 18 month terms
- **Interest calculation methods**: Simple (accrued daily) or precomputed (fixed per payment)
- **Grace periods**: Automatic interest capitalization during grace periods
- **Interest-only periods**: Configure initial interest-only payment phases
- **Fee handling**: Origination fees and additional fees with three treatment options
- **Bank day calculations**: Automatically skip weekends and US Federal Reserve holidays
- **Multiple output formats**: Console display or CSV export
- **Comprehensive testing**: 29 RSpec tests with 100% pass rate

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

### Basic Example

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-11-15",
  principal: 100000.00,
  term_months: 12,
  annual_rate: 17.75,
  frequency: :daily
)

# Display in console
schedule.generate

# Generate CSV file
schedule.generate(output: :csv, csv_path: "schedule.csv")
```

### Advanced Example with All Features

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-11-15",
  principal: 100000.00,
  term_months: 12,
  annual_rate: 17.75,
  frequency: :daily,
  origination_fee: 10000.00,           # Added to principal
  additional_fee: 2500.00,             # Additional fee
  additional_fee_label: "Processing Fee" # Additional fee label Example: Processing fee
  additional_fee_treatment: :distributed, # Options: :distributed, :add_to_principal, :separate_payment
  bank_days_only: true,                # Skip weekends & holidays
  interest_only_periods: 10,           # First 10 payments are interest-only
  grace_period_days: 3,                # 3-day grace period
  interest_method: :simple             # Options: :simple, :precomputed
)

schedule.generate
```

## Command Line Interface

Amortizy includes an interactive CLI tool:

```bash
amortizy
```

The CLI provides:
1. Run default examples (demonstrates simple vs precomputed interest)
2. Enter parameters manually with interactive prompts
3. Automatic CSV generation option

## API Reference

### Initialization Parameters

| Parameter | Type | Required | Default | Options | Description |
|-----------|------|----------|---------|---------|-------------|
| `start_date` | String/Date | Yes | - | YYYY-MM-DD | Loan start date |
| `principal` | Float | Yes | - | - | Loan principal amount |
| `term_months` | Integer | Yes | - | 6, 9, 12, 15, 18 | Loan term in months |
| `annual_rate` | Float | Yes | - | - | Annual interest rate (%) |
| `frequency` | Symbol | Yes | - | `:daily`, `:weekly` | Payment frequency |
| `origination_fee` | Float | No | 0 | - | Fee added to principal |
| `additional_fee` | Float | No | 0 | - | Additional processing fee |
| `additional_fee_label` | String | No | "Additional Fee" | - | Label for additional fee |
| `additional_fee_treatment` | Symbol | No | `:distributed` | `:distributed`, `:add_to_principal`, `:separate_payment` | How to handle additional fee |
| `bank_days_only` | Boolean | No | false | - | Skip weekends and holidays |
| `interest_only_periods` | Integer | No | 0 | - | Number of interest-only payments |
| `grace_period_days` | Integer | No | 0 | - | Days before first payment |
| `interest_method` | Symbol | No | `:simple` | `:simple`, `:precomputed` | Interest calculation method |

### Methods

#### `generate(output: :console, csv_path: nil)`

Generate the amortization schedule.

**Parameters:**
- `output` (Symbol): `:console` or `:csv`
- `csv_path` (String): Required if output is `:csv`

**Returns:** `nil` (outputs to console or file)

**Example:**
```ruby
# Console output
schedule.generate

# CSV output
schedule.generate(output: :csv, csv_path: "my_schedule.csv")
```

## Fee Treatment Options

### 1. Distributed (`:distributed`)
The fee is spread evenly across all payments.

```ruby
additional_fee_treatment: :distributed
```

**Best for:** Keeping individual payments manageable while recovering fees over time

### 2. Add to Principal (`:add_to_principal`)
The fee is added to the loan principal upfront, increasing the base amount financed.

```ruby
additional_fee_treatment: :add_to_principal
```

**Best for:** Rolling all costs into the loan amount

### 3. Separate Payment (`:separate_payment`)
The fee is collected as a separate first payment before regular amortization begins.

```ruby
additional_fee_treatment: :separate_payment
```

**Best for:** Collecting fees upfront separately from the loan repayment

## Interest Calculation Methods

### Simple Interest (`:simple`)

Interest accrues daily on the remaining principal balance. As you pay down the principal, interest payments decrease over time.

**Formula:** Daily interest = (Principal Balance × Annual Rate) / 365

**Characteristics:**
- Interest decreases as principal is paid down
- Lower total interest cost
- More principal goes toward balance reduction in later payments

**Best for:** Traditional amortizing loans, consumer loans

```ruby
interest_method: :simple
```

### Precomputed Interest (`:precomputed`)

Total interest is calculated upfront based on the original principal and divided equally across all payments. Interest per payment stays constant regardless of principal reduction.

**Formula:** Total interest calculated at start, then divided by number of payments

**Characteristics:**
- Interest payment stays constant throughout loan
- Higher total interest cost
- Simpler payment structure

**Best for:** Fixed payment structures, certain consumer loan types

```ruby
interest_method: :precomputed
```

## Federal Bank Holidays

When `bank_days_only: true`, the schedule automatically skips:

### Weekends
- Saturday
- Sunday

### US Federal Reserve Holidays (11 total)
- New Year's Day (January 1)
- Martin Luther King Jr. Birthday (Third Monday in January)
- Presidents' Day / Washington's Birthday (Third Monday in February)
- Memorial Day (Last Monday in May)
- Juneteenth National Independence Day (June 19)
- Independence Day (July 4)
- Labor Day (First Monday in September)
- Columbus Day (Second Monday in October)
- Veterans Day (November 11)
- Thanksgiving Day (Fourth Thursday in November)
- Christmas Day (December 25)

**Weekend Observation Rules:**
- Holidays falling on Saturday → observed on preceding Friday
- Holidays falling on Sunday → observed on following Monday

These rules are automatically handled by the `holidays` gem.

## Usage Examples

### Example 1: Simple Daily Loan

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-01-15",
  principal: 50000.00,
  term_months: 6,
  annual_rate: 12.0,
  frequency: :daily
)

schedule.generate
```

### Example 2: Weekly Loan with Grace Period

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-01-15",
  principal: 75000.00,
  term_months: 12,
  annual_rate: 15.0,
  frequency: :weekly,
  grace_period_days: 7  # One week grace period
)

schedule.generate
```

### Example 3: Interest-Only with Bank Days

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-01-15",
  principal: 100000.00,
  term_months: 18,
  annual_rate: 10.0,
  frequency: :weekly,
  interest_only_periods: 8,   # First 8 weeks interest-only
  bank_days_only: true         # Skip weekends and holidays
)

schedule.generate
```

### Example 4: Complex Commercial Loan

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-01-15",
  principal: 250000.00,
  term_months: 18,
  annual_rate: 14.5,
  frequency: :daily,
  origination_fee: 25000.00,
  additional_fee: 5000.00,
  additional_fee_label: "Processing Fee",
  additional_fee_treatment: :distributed,
  bank_days_only: true,
  interest_only_periods: 20,
  grace_period_days: 5,
  interest_method: :simple
)

schedule.generate(output: :csv, csv_path: "commercial_loan.csv")
```

## Programmatic Access

Access schedule data directly for custom processing:

```ruby
require 'amortizy'

schedule = Amortizy::AmortizationSchedule.new(
  start_date: "2025-01-15",
  principal: 50000.00,
  term_months: 12,
  annual_rate: 10.0,
  frequency: :daily
)

# Get raw schedule data
schedule_data = schedule.send(:generate_schedule_data)

# Process each payment
schedule_data.each do |payment|
  puts "Payment #{payment[:payment_number]}"
  puts "  Date: #{payment[:date]}"
  puts "  Principal: $#{'%.2f' % payment[:principal_payment]}"
  puts "  Interest: $#{'%.2f' % payment[:interest_payment]}"
  puts "  Balance: $#{'%.2f' % payment[:principal_balance]}"
end

# Calculate totals
total_interest = schedule_data.sum { |row| row[:interest_payment] || 0 }
total_principal = schedule_data.sum { |row| row[:principal_payment] || 0 }

puts "\nLoan Summary:"
puts "Total Interest Paid: $#{'%.2f' % total_interest}"
puts "Total Principal Paid: $#{'%.2f' % total_principal}"
puts "Total Amount Paid: $#{'%.2f' % (total_interest + total_principal)}"
```

## Output Formats

### Console Output

Formatted table display with columns:
- Payment number
- Payment date
- Days in period
- Principal payment
- Interest payment
- Additional fee payment (if applicable)
- Total payment
- Principal balance
- Accrued interest
- Total balance
- Payment type (Regular, Interest Only, Grace Period, etc.)

### CSV Output

Same data as console output in spreadsheet-compatible CSV format. Suitable for:
- Excel/Google Sheets import
- Financial analysis and reporting
- Data visualization
- Record keeping and audits
- Integration with other systems

## Requirements

- Ruby 2.7 or higher
- `holidays` gem (~> 8.0) - automatically installed as a dependency

## Development

After checking out the repo, run:

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run interactive console
bin/console

# Install gem locally for testing
gem install ./amortizy-1.0.0.gem
```

## Testing

Amortizy includes a comprehensive RSpec test suite with 29 test cases covering:

- Initialization and validation
- Payment calculations
- Effective principal calculations
- Schedule generation
- Interest methods (simple vs precomputed)
- Grace periods
- Interest-only periods
- Bank day functionality
- Federal holiday detection
- Fee treatments
- CSV generation
- Total payment calculations

Run the test suite:

```bash
bundle exec rspec
```

## Use Cases

Amortizy is perfect for:

- **Financial service applications** - Build loan calculators and amortization tools
- **Lending platforms** - Generate accurate payment schedules for borrowers
- **Consumer lending** - Handle personal loans, installment loans, and lines of credit
- **Business lending** - Manage commercial loans with complex terms
- **Financial modeling** - Analyze different loan scenarios and structures
- **Payment processing systems** - Generate schedules for automated payment processing
- **Financial education** - Demonstrate how loan payments and interest work
- **Comparison tools** - Help users compare different loan options

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

### Reporting Issues

When reporting issues, please include:
- Ruby version (`ruby -v`)
- Gem version
- Steps to reproduce
- Expected vs actual behavior
- Any error messages

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Author

**Rich Zapata** - [@zapatify](https://github.com/zapatify)

## Acknowledgments

- Built with [Bundler](https://bundler.io/) gem structure
- Uses the [holidays](https://github.com/holidays/holidays) gem for accurate federal holiday detection
- Inspired by the need for flexible, accurate loan amortization tools in Ruby

## Support

- 📫 Report issues: [GitHub Issues](https://github.com/zapatify/amortizy/issues)
- 📖 Documentation: [GitHub Repository](https://github.com/zapatify/amortizy)
- 💎 RubyGems: [rubygems.org/gems/amortizy](https://rubygems.org/gems/amortizy)

---

**Made with ❤️ for the Ruby community**
