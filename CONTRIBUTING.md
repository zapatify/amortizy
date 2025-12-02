# Contributing to Amortizy

First off, thank you for considering contributing to Amortizy! It's people like you that make Amortizy such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by the principle of respect and professionalism. By participating, you are expected to uphold this standard.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the [existing issues](https://github.com/zapatify/amortizy/issues) to avoid duplicates.

When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples** - Include code snippets, loan parameters, or output
* **Describe the behavior you observed** and what you expected to see
* **Include your environment details**:
  - Ruby version (`ruby -v`)
  - Amortizy version (`gem list amortizy`)
  - Operating system

**Example Bug Report:**

```
Title: Grace period interest not capitalizing correctly for weekly frequency

Description:
When using weekly payment frequency with a 7-day grace period, the interest 
is not being properly capitalized into the principal.

Steps to Reproduce:
1. Create schedule with weekly frequency
2. Set grace_period_days to 7
3. Generate schedule
4. Check effective principal

Expected: Principal should increase by ~7 days of interest
Actual: Principal remains unchanged

Environment:
- Ruby 3.2.0
- Amortizy 1.0.0
- macOS Sonoma
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a detailed description** of the suggested enhancement
* **Explain why this enhancement would be useful** to most Amortizy users
* **List any similar features** in other tools if applicable

**Example Enhancement Request:**

```
Title: Add monthly payment frequency option

Description:
Currently Amortizy supports daily and weekly frequencies. Adding monthly 
would be useful for traditional mortgage-style loans.

Use Case:
Many personal and business loans use monthly payments. This would make 
Amortizy useful for a broader range of applications.

Similar Features:
- Most online loan calculators support monthly
- Banking systems typically use monthly
```

### Pull Requests

Pull requests are the best way to propose changes to the codebase.

1. **Fork the repo** and create your branch from `main`
2. **Make your changes**
3. **Add tests** if you've added code that should be tested
4. **Ensure the test suite passes** (`bundle exec rspec`)
5. **Update documentation** if needed
6. **Write a clear commit message**
7. **Open a Pull Request**

#### Pull Request Guidelines

* Follow the existing code style
* Write clear, descriptive commit messages
* Include tests for new functionality
* Update README.md if adding features
* Update CHANGELOG.md under [Unreleased]
* Keep PRs focused - one feature/fix per PR

**Example PR Description:**

```
## Description
Adds support for bi-weekly payment frequency

## Changes
- Added :biweekly to frequency validation
- Updated payment calculations for bi-weekly schedules
- Added tests for bi-weekly frequency
- Updated README with bi-weekly examples

## Testing
- All existing tests pass
- Added 3 new tests for bi-weekly functionality
- Manually tested with various loan parameters

## Documentation
- Updated README.md with bi-weekly examples
- Updated API reference table
- Added to CHANGELOG.md
```

## Development Setup

### Prerequisites

```bash
# Install Ruby 2.7 or higher
ruby -v

# Install Bundler
gem install bundler
```

### Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/amortizy.git
cd amortizy

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run the CLI
bundle exec exe/amortizy
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/engine_spec.rb

# Run with coverage (if configured)
COVERAGE=true bundle exec rspec
```

### Code Style

* Follow Ruby community style guidelines
* Use 2 spaces for indentation (not tabs)
* Keep lines under 100 characters when reasonable
* Use meaningful variable and method names
* Add comments for complex logic

**Good Example:**
```ruby
def calculate_daily_interest(principal, annual_rate)
  # Convert annual rate to daily and multiply by principal
  (principal * annual_rate) / 365.0
end
```

**Bad Example:**
```ruby
def calc(p,r)
  p*r/365.0 # calculate interest
end
```

## Project Structure

```
amortizy/
├── lib/
│   ├── amortizy.rb              # Main entry point
│   └── amortizy/
│       ├── version.rb           # Version number
│       └── engine.rb            # Core logic
├── spec/
│   ├── spec_helper.rb           # RSpec configuration
│   └── engine_spec.rb           # Main test file
└── amortizy.gemspec             # Gem specification
```

## Testing Guidelines

### Writing Tests

* Use descriptive test names
* Follow Arrange-Act-Assert pattern
* Test both happy paths and edge cases
* Mock external dependencies when appropriate

**Example Test:**
```ruby
describe 'grace period' do
  it 'capitalizes interest during grace period' do
    # Arrange
    schedule = Amortizy::AmortizationSchedule.new(
      start_date: "2025-01-15",
      principal: 100000.00,
      term_months: 12,
      annual_rate: 10.0,
      frequency: :daily,
      grace_period_days: 5
    )
    
    # Act
    effective_principal = schedule.send(:effective_principal)
    
    # Assert
    expect(effective_principal).to be > 100000.00
    expect(effective_principal).to be < 100200.00
  end
end
```

## Commit Message Guidelines

Write clear, concise commit messages that explain what and why:

```bash
# Good commit messages
git commit -m "Add bi-weekly payment frequency support"
git commit -m "Fix interest calculation for leap years"
git commit -m "Update README with precomputed interest examples"

# Bad commit messages
git commit -m "fix bug"
git commit -m "updates"
git commit -m "wip"
```

For larger commits, use multi-line messages:

```bash
git commit -m "Add support for adjustable rate mortgages

- Add rate_changes parameter to accept rate change schedule
- Update interest calculation to handle variable rates
- Add comprehensive tests for ARM scenarios
- Update documentation with ARM examples

Closes #42"
```

## Documentation

When adding features, update:

1. **README.md** - Add usage examples
2. **CHANGELOG.md** - Add to [Unreleased] section
3. **Code comments** - Explain complex logic
4. **RDoc/YARD** - Document public methods (if applicable)

## Release Process

(For maintainers)

1. Update version in `lib/amortizy/version.rb`
2. Update CHANGELOG.md with release date
3. Commit changes: `git commit -am "Bump version to X.Y.Z"`
4. Create tag: `git tag -a vX.Y.Z -m "Version X.Y.Z"`
5. Push: `git push && git push --tags`
6. Build: `gem build amortizy.gemspec`
7. Publish: `gem push amortizy-X.Y.Z.gem`

## Questions?

Feel free to open an issue with the label "question" or reach out to the maintainers.

## Thank You!

Your contributions to open source, large or small, make projects like this possible. Thank you for taking the time to contribute.
