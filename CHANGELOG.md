# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing currently.

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

- Additional payment frequencies (monthly, bi-weekly)
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
