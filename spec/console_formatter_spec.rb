# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Amortizy::ConsoleFormatter do
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  describe '#render' do
    it 'outputs schedule with header and summary' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 10_000.00,
        term_months: 3,
        frequency: :monthly,
        annual_rate: 10.0
      )
      output = capture_stdout { described_class.new(schedule).render }
      expect(output).to include('LOAN SUMMARY')
      expect(output).to include('Payment')
      expect(output).to include('Regular Payment')
    end

    it 'displays grace period rows when present' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 10_000.00,
        term_months: 3,
        frequency: :monthly,
        annual_rate: 10.0,
        grace_period_days: 5
      )
      output = capture_stdout { described_class.new(schedule).render }
      expect(output).to include('Grace')
    end

    it 'displays custom additional fee label' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 10_000.00,
        term_months: 3,
        frequency: :monthly,
        annual_rate: 10.0,
        additional_fee_label: 'Platform Fee'
      )
      output = capture_stdout { described_class.new(schedule).render }
      expect(output).to include('Platform Fee')
    end
  end
end
