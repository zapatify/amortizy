# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-04-20

### Added

#### Commercial Financing Disclosure Module
- **`Amortizy::Disclosure`** - new class that computes disclosure data elements for
  closed-end commercial loan transactions per California SB 1235 (Title 10, Chapter 3)
- **APR calculation** using the actuarial method per Appendix J of Regulation Z
  (12 CFR Part 1026, section 940) with Newton-Raphson solver and bisection fallback
- **Finance charge** - total dollar cost of financing including interest and all fees (section 943)
- **Amount financed** - principal adjusted for prepaid finance charges (section 900(a)(1)(B))
- **Recipient funds** - net amount disbursed to borrower after third-party payoffs (section 900(a)(26))
- **Term display** - formatted per regulation: days for terms <= 1 year,
  years/months for longer terms (section 901(a)(4))
- **Average monthly cost** - automatically computed for non-monthly payment frequencies (section 910(a)(12))
- **Prepayment information** - structured data for prepayment penalty disclosures (section 910(a)(8-10))
- **`#to_h`** - flat hash of all computed values
- **`#to_labeled_h`** - hash with regulation-correct labels from section 910

#### Design Notes
- Disclosure class wraps an existing `AmortizationSchedule` — no changes to the engine API
- Values are jurisdiction-agnostic: computed per the most stringent methodology (California),
  usable for any state's commercial financing disclosure requirements
- Origination fee is treated as a prepaid finance charge by default
- APR rounded to nearest 10 basis points per section 901(a)(5)
- APR accuracy within 1/8 of 1 percentage point tolerance per section 955

## [2.0.0] - 2026-04-19

### Added

#### Dynamic Payment Engine
- **Monthly payment frequency** - the most common loan payment type, now supported
- **Bi-weekly payment frequency** - every 14 days
- **`num_payments` input** - specify exact payment count instead of term length
- **Any term length** - no longer restricted to 6, 9, 12, 15, 18 months
- Dynamic payment count calculation based on frequency and term

#### Public API
- `#schedule` - returns frozen array of payment hashes (replaces private `generate_schedule_data`)
- `#summary` - returns hash with loan totals, dates, and payment info
- `#end_date` - last payment date
- `#total_interest` - sum of all interest payments
- `#total_paid` - sum of all payments
- `#payment_amount` - regular payment amount

#### Code Organization
- Extracted `ConsoleFormatter` for terminal output
- Extracted `CsvFormatter` for CSV export
- Engine class now focused on amortization math only

### Changed
- `term_months` is now optional (provide `term_months` OR `num_payments`, not both)
- Removed hardcoded payment count lookup table - all counts calculated dynamically
- Minimum Ruby version bumped to 3.0

### Breaking Changes
- `term_months` is no longer a required keyword argument
- **Daily frequency payment counts changed significantly.** v1.0 used a hardcoded lookup table with business-day-approximate counts (e.g., 248 payments for 12 months). v2.0 calculates dynamically using calendar days (365 for 12 months) unless `bank_days_only: true` is set. This is a ~47% increase in payment count for daily-frequency loans without `bank_days_only`. If your application relied on v1.0 daily payment counts, set `bank_days_only: true` to get business-day counts, or use `num_payments` to specify the exact count.
- Weekly frequency payment counts may differ by 0-1 due to rounding in dynamic calculation
- `principal` must now be positive (zero and negative values raise `ArgumentError`)

## [1.0.0] - 2024-12-02

### Added

#### Core Features
- Initial release of Amortizy gem
- Daily payment frequency support
- Weekly payment frequency support
- Flexible loan terms: 6, 9, 12, 15, and 18 months
- Simple interest calculation method (accrued daily)
- Precomputed interest calculation method (fixed per payment)

#### Advanced Loan Features
- Grace period handling with automatic interest capitalization
- Interest-only payment periods
- Origination fee support (added to principal)
- Additional fee support with three treatment options:
  - Distributed across all payments
  - Added to principal upfront
  - Collected as separate first payment

#### Bank Day Calculations
- Weekend skipping (Saturday/Sunday)
- US Federal Reserve holiday support (11 holidays)
- Automatic weekend observation rules for holidays

#### Output Options
- Console output with formatted tables
- CSV export functionality
- Programmatic access to schedule data

#### Testing
- Comprehensive RSpec test suite with 29 test cases
- 100% test pass rate
- Coverage of all features and edge cases

#### Documentation
- Complete README with API reference
- Usage examples for common scenarios
- Detailed parameter documentation
- Contributing guidelines

### Dependencies
- holidays gem (~> 8.0) for federal holiday detection
- RSpec (~> 3.0) for testing

### Requirements
- Ruby 2.7 or higher

---

## Version History

### [1.0.0] - 2024-12-02
Initial public release

---

## Upgrade Guide

### From Pre-release to 1.0.0

If you were testing pre-release versions, upgrade by:

```bash
gem uninstall amortizy
gem install amortizy
```

Or in your Gemfile:

```ruby
gem 'amortizy', '~> 1.0'
```

Then run:

```bash
bundle update amortizy
```

---

## Future Plans

Potential features for future releases:

- More interest calculation methods
- Support for additional holiday calendars (state, international)
- Balloon payment support
- Variable interest rates
- Payment modification capabilities
- Enhanced reporting formats

---

## Links

- [RubyGems](https://rubygems.org/gems/amortizy)
- [GitHub Repository](https://github.com/zapatify/amortizy)
- [Issue Tracker](https://github.com/zapatify/amortizy/issues)
