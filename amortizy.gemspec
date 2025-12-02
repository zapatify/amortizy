# frozen_string_literal: true

require_relative "lib/amortizy/version"

Gem::Specification.new do |spec|
  spec.name = "amortizy"
  spec.version = Amortizy::VERSION
  spec.authors = ["Rich Zapata"]
  spec.email = ["rzapata@gmail.com"]

  spec.summary = "A gem to generate amortization schedules"
  spec.description = "A comprehensive Ruby gem for generating loan amortization schedules with advanced features including grace periods, interest-only payments, federal bank holidays, and multiple interest calculation methods"
  spec.homepage = "https://github.com/zapatify/amortizy"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zapatify/amortizy"
  spec.metadata["changelog_uri"] = "https://github.com/zapatify/amortizy/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "holidays", "~> 8.0"
  spec.add_development_dependency "rubocop", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
