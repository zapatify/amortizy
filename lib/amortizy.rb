# frozen_string_literal: true

require_relative 'amortizy/version'
require_relative 'amortizy/engine'
require_relative 'amortizy/console_formatter'
require_relative 'amortizy/csv_formatter'

module Amortizy
  class Error < StandardError; end
end
