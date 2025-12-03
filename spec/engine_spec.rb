# frozen_string_literal: true

require 'rspec'
require 'date'
require 'holidays'
require 'spec_helper'
require 'fileutils'

RSpec.describe Amortizy::AmortizationSchedule do
  # Test initialization and validation

  describe 'initialization' do
    it 'initializes with valid parameters' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily
      )
      expect(schedule.start_date).to eq(Date.parse('2025-11-15'))
      expect(schedule.principal).to eq(100_000.00)
      expect(schedule.term_months).to eq(12)
    end

    it 'raises error for invalid term months' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 7,
          annual_rate: 17.75,
          frequency: :daily
        )
      end.to raise_error(ArgumentError, /Term must be/)
    end

    it 'raises error for invalid frequency' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :monthly
        )
      end.to raise_error(ArgumentError, /Frequency must be/)
    end

    it 'raises error for invalid interest method' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily,
          interest_method: :compound
        )
      end.to raise_error(ArgumentError, /Interest method must be/)
    end

    it 'raises error for invalid fee treatment' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily,
          additional_fee_treatment: :invalid
        )
      end.to raise_error(ArgumentError, /Additional fee treatment must be/)
    end
  end

  # Test payment calculations

  describe 'payment calculations' do
    it 'calculates correct daily payment count for 6 months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily
      )
      expect(schedule.send(:calculate_total_payments)).to eq(124)
    end

    it 'calculates correct daily payment count for 12 months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 12,
        annual_rate: 15.0,
        frequency: :daily
      )
      expect(schedule.send(:calculate_total_payments)).to eq(248)
    end

    it 'calculates correct weekly payment count for 12 months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 12,
        annual_rate: 15.0,
        frequency: :weekly
      )
      expect(schedule.send(:calculate_total_payments)).to eq(53)
    end
  end

  # Test effective principal calculations

  describe 'effective principal calculations' do
    it 'includes origination fee in effective principal' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        origination_fee: 10_000.00
      )
      expect(schedule.send(:effective_principal)).to eq(110_000.00)
    end

    it 'adds additional fee to principal when treatment is add_to_principal' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        origination_fee: 10_000.00,
        additional_fee: 5000.00,
        additional_fee_treatment: :add_to_principal
      )
      expect(schedule.send(:effective_principal)).to eq(115_000.00)
    end

    it 'capitalizes interest during grace period' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        origination_fee: 10_000.00,
        grace_period_days: 3
      )
      effective = schedule.send(:effective_principal)
      expect(effective).to be > 110_000.00
      expect(effective).to be < 110_500.00
    end
  end

  # Test schedule generation

  describe 'schedule generation' do
    it 'generates correct number of payments' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        bank_days_only: false
      )
      schedule_data = schedule.send(:generate_schedule_data)
      regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }
      expect(regular_payments.length).to eq(124)
    end

    it 'fully amortizes the loan' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        origination_fee: 1000.00,
        bank_days_only: false,
        interest_method: :simple
      )
      schedule_data = schedule.send(:generate_schedule_data)
      final_payment = schedule_data.last
      expect(final_payment[:principal_balance]).to be < 0.02
    end
  end

  # Test interest methods

  describe 'interest methods' do
    context 'simple interest' do
      it 'decreases over time as balance decreases' do
        schedule = Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily,
          bank_days_only: false,
          interest_method: :simple
        )
        schedule_data = schedule.send(:generate_schedule_data)
        regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }

        first_interest = regular_payments.first[:interest_payment]
        last_interest = regular_payments.last[:interest_payment]

        expect(first_interest).to be > last_interest
      end
    end

    context 'precomputed interest' do
      it 'remains constant across all payments' do
        schedule = Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily,
          bank_days_only: false,
          interest_method: :precomputed
        )
        schedule_data = schedule.send(:generate_schedule_data)
        regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }

        first_interest = regular_payments.first[:interest_payment]
        last_interest = regular_payments.last[:interest_payment]

        expect(first_interest).to be_within(0.01).of(last_interest)
      end

      it 'costs more than simple interest' do
        simple_schedule = Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily,
          origination_fee: 10_000.00,
          bank_days_only: false,
          interest_method: :simple
        )

        precomputed_schedule = Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily,
          origination_fee: 10_000.00,
          bank_days_only: false,
          interest_method: :precomputed
        )

        simple_data = simple_schedule.send(:generate_schedule_data)
        precomputed_data = precomputed_schedule.send(:generate_schedule_data)

        simple_total_interest = simple_data.sum { |row| row[:interest_payment] || 0 }
        precomputed_total_interest = precomputed_data.sum { |row| row[:interest_payment] || 0 }

        expect(precomputed_total_interest).to be > simple_total_interest
      end
    end
  end

  # Test grace period

  describe 'grace period' do
    it 'adds capitalized interest to principal' do
      without_grace = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        grace_period_days: 0
      )

      with_grace = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        grace_period_days: 10
      )

      without_grace_principal = without_grace.send(:effective_principal)
      with_grace_principal = with_grace.send(:effective_principal)

      expect(with_grace_principal).to be > without_grace_principal
    end

    it 'appears in the schedule' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        grace_period_days: 5
      )
      schedule_data = schedule.send(:generate_schedule_data)

      grace_row = schedule_data.find { |row| row[:payment_type] == 'Grace Period' }
      expect(grace_row).not_to be_nil
      expect(grace_row[:days_in_period]).to eq(5)
    end
  end

  # Test interest-only periods

  describe 'interest-only periods' do
    it 'has zero principal payment during interest-only periods' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        interest_only_periods: 10,
        bank_days_only: false
      )
      schedule_data = schedule.send(:generate_schedule_data)

      first_10_payments = schedule_data.select do |row|
        row[:payment_number].is_a?(Integer) && row[:payment_number] <= 10
      end

      first_10_payments.each do |payment|
        expect(payment[:principal_payment]).to eq(0.0)
        expect(payment[:payment_type]).to eq('Interest Only')
      end
    end
  end

  # Test bank days functionality

  describe 'bank days functionality' do
    it 'skips weekends when bank_days_only is true' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-14',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        bank_days_only: true
      )

      schedule_data = schedule.send(:generate_schedule_data)
      regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }

      regular_payments.each do |payment|
        expect(payment[:date].saturday?).to be_falsey
        expect(payment[:date].sunday?).to be_falsey
      end
    end

    it 'skips federal holidays when bank_days_only is true' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-12-24',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        bank_days_only: true
      )

      schedule_data = schedule.send(:generate_schedule_data)
      regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }

      christmas = Date.new(2025, 12, 25)
      payment_dates = regular_payments.map { |p| p[:date] }
      expect(payment_dates).not_to include(christmas)
    end
  end

  # Test holiday detection

  describe 'holiday detection' do
    let(:schedule) do
      Amortizy::AmortizationSchedule.new(
        start_date: '2025-01-01',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily
      )
    end

    it 'detects federal holidays' do
      new_years = Date.new(2025, 1, 1)
      expect(schedule.send(:federal_holiday?, new_years)).to be_truthy

      regular_day = Date.new(2025, 1, 2)
      expect(schedule.send(:federal_holiday?, regular_day)).to be_falsey
    end

    it 'detects observed holidays' do
      observed_friday = Date.new(2026, 7, 3)
      actual_saturday = Date.new(2026, 7, 4)

      holidays_friday = Holidays.on(observed_friday, :federalreserve, :observed)
      holidays_saturday = Holidays.on(actual_saturday, :federalreserve, :observed)

      expect(holidays_friday.empty? && holidays_saturday.empty?).to be_falsey
    end

    it 'includes weekend check in bank_day? method' do
      schedule_with_bank_days = Amortizy::AmortizationSchedule.new(
        start_date: '2025-01-01',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        bank_days_only: true
      )

      saturday = Date.new(2025, 1, 4)
      expect(schedule_with_bank_days.send(:bank_day?, saturday)).to be_falsey

      sunday = Date.new(2025, 1, 5)
      expect(schedule_with_bank_days.send(:bank_day?, sunday)).to be_falsey

      weekday = Date.new(2025, 1, 6)
      expect(schedule_with_bank_days.send(:bank_day?, weekday)).to be_truthy
    end

    it 'skips holidays and weekends with next_bank_day' do
      schedule_with_bank_days = Amortizy::AmortizationSchedule.new(
        start_date: '2025-12-24',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        bank_days_only: true
      )

      start_date = Date.new(2025, 12, 24)
      next_day = schedule_with_bank_days.send(:next_bank_day, start_date + 1)

      expect(schedule_with_bank_days.send(:bank_day?, next_day)).to be_truthy
      expect(next_day.saturday?).to be_falsey
      expect(next_day.sunday?).to be_falsey
    end
  end

  # Test fee treatments

  describe 'fee treatments' do
    context 'distributed fee treatment' do
      it 'adds fee amount to each payment' do
        schedule = Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 10_000.00,
          term_months: 6,
          annual_rate: 15.0,
          frequency: :daily,
          additional_fee: 124.00,
          additional_fee_treatment: :distributed,
          bank_days_only: false
        )

        schedule_data = schedule.send(:generate_schedule_data)
        regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }

        regular_payments.each do |payment|
          expect(payment[:additional_fee_payment]).to be_within(0.01).of(1.00)
        end
      end
    end

    context 'separate fee payment' do
      it 'creates a separate fee payment entry' do
        schedule = Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 10_000.00,
          term_months: 6,
          annual_rate: 15.0,
          frequency: :daily,
          additional_fee: 500.00,
          additional_fee_treatment: :separate_payment,
          bank_days_only: false
        )

        schedule_data = schedule.send(:generate_schedule_data)

        fee_payment = schedule_data.find { |row| row[:payment_type] == 'Additional Fee Payment' }
        expect(fee_payment).not_to be_nil
        expect(fee_payment[:additional_fee_payment]).to eq(500.00)
      end
    end
  end

  # Test CSV generation

  describe 'CSV generation' do
    it 'generates a valid CSV file' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily
      )

      csv_path = 'test_output.csv'
      FileUtils.rm_f(csv_path)

      schedule.generate(output: :csv, csv_path: csv_path)

      expect(File.exist?(csv_path)).to be_truthy

      content = File.read(csv_path)
      expect(content).to include('Payment Number')
      expect(content).to include('Principal Payment')

      FileUtils.rm_f(csv_path)
    end
  end

  # Test total payment calculation

  describe 'total payment calculation' do
    it 'equals the sum of all payment components' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 6,
        annual_rate: 15.0,
        frequency: :daily,
        origination_fee: 1000.00,
        additional_fee: 100.00,
        additional_fee_treatment: :distributed,
        bank_days_only: false
      )

      schedule_data = schedule.send(:generate_schedule_data)
      regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }

      regular_payments.each do |payment|
        expected_total = payment[:principal_payment] +
                         payment[:interest_payment] +
                         payment[:additional_fee_payment]

        expect(payment[:total_payment]).to be_within(0.01).of(expected_total)
      end
    end
  end
end

puts "\nTo run these tests, use: rspec amortization_spec.rb"
puts '=' * 80
