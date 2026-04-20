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

    it 'raises error for zero principal' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 0,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily
        )
      end.to raise_error(ArgumentError, /principal must be positive/)
    end

    it 'raises error for negative principal' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: -5000,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :daily
        )
      end.to raise_error(ArgumentError, /principal must be positive/)
    end

    it 'raises error for invalid term months' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 0,
          annual_rate: 17.75,
          frequency: :daily
        )
      end.to raise_error(ArgumentError, /term_months must be a positive integer/)
    end

    it 'raises error for invalid frequency' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2025-11-15',
          principal: 100_000.00,
          term_months: 12,
          annual_rate: 17.75,
          frequency: :quarterly
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
      expect(schedule.send(:total_payments)).to eq(181)
    end

    it 'calculates correct daily payment count for 12 months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 12,
        annual_rate: 15.0,
        frequency: :daily
      )
      expect(schedule.send(:total_payments)).to eq(365)
    end

    it 'calculates correct weekly payment count for 12 months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-11-15',
        principal: 10_000.00,
        term_months: 12,
        annual_rate: 15.0,
        frequency: :weekly
      )
      expect(schedule.send(:total_payments)).to eq(52)
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
      expect(regular_payments.length).to eq(181)
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
          num_payments: 100,
          annual_rate: 15.0,
          frequency: :daily,
          additional_fee: 100.00,
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

  describe 'grace periods' do
    # ... existing tests ...

    it 'advances grace period end to next bank day when it falls on weekend' do
      # Grace period ends on Saturday Dec 27, 2025
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-12-24',  # Wednesday
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        grace_period_days: 3,      # Ends on Saturday 12/27
        bank_days_only: true
      )

      first_payment = schedule.send(:first_payment_date)

      # Should advance to Monday 12/29 (skipping weekend)
      expect(first_payment).to eq(Date.new(2025, 12, 29))
      expect(first_payment.monday?).to be_truthy
    end

    it 'advances grace period end to next bank day when it falls on holiday' do
      # Grace period ends on Christmas (12/25/2025 - Thursday)
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2025-12-22',  # Monday
        principal: 100_000.00,
        term_months: 12,
        annual_rate: 17.75,
        frequency: :daily,
        grace_period_days: 3,      # Ends on Christmas 12/25
        bank_days_only: true
      )

      first_payment = schedule.send(:first_payment_date)

      # Should advance to Friday 12/26 (day after Christmas)
      expect(first_payment).to eq(Date.new(2025, 12, 26))
    end
  end
  # Test dual input model (term_months OR num_payments)

  describe 'dual input model' do
    it 'accepts num_payments instead of term_months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        num_payments: 24,
        frequency: :weekly,
        annual_rate: 10.0
      )
      expect(schedule.send(:total_payments)).to eq(24)
    end

    it 'raises error when both term_months and num_payments are provided' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000.00,
          term_months: 12,
          num_payments: 24,
          frequency: :weekly,
          annual_rate: 10.0
        )
      end.to raise_error(ArgumentError, /Cannot specify both/)
    end

    it 'raises error when neither term_months nor num_payments is provided' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000.00,
          frequency: :weekly,
          annual_rate: 10.0
        )
      end.to raise_error(ArgumentError, /Must specify either/)
    end

    it 'accepts any positive integer for term_months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        term_months: 36,
        frequency: :weekly,
        annual_rate: 10.0
      )
      expect(schedule.term_months).to eq(36)
    end

    it 'calculates num_payments dynamically for weekly frequency' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        term_months: 12,
        frequency: :weekly,
        annual_rate: 10.0
      )
      # 12 months ~ 52 weeks
      expect(schedule.send(:total_payments)).to eq(52)
    end

    it 'calculates num_payments dynamically for daily frequency' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        term_months: 12,
        frequency: :daily,
        annual_rate: 10.0
      )
      # 12 months = 365 calendar days
      expect(schedule.send(:total_payments)).to eq(365)
    end

    it 'calculates num_payments for daily with bank_days_only' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        term_months: 12,
        frequency: :daily,
        annual_rate: 10.0,
        bank_days_only: true
      )
      payments = schedule.send(:total_payments)
      # ~252 business days in a year, give or take
      expect(payments).to be_between(248, 254)
    end

    it 'fully amortizes with num_payments input' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        num_payments: 52,
        frequency: :weekly,
        annual_rate: 12.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      final_payment = schedule_data.last
      expect(final_payment[:principal_balance]).to be < 0.02
    end
  end

  # Test monthly and biweekly frequencies

  describe 'monthly frequency' do
    it 'accepts monthly frequency' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :monthly,
        annual_rate: 10.0
      )
      expect(schedule.send(:total_payments)).to eq(12)
    end

    it 'generates correct number of monthly payments' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 24,
        frequency: :monthly,
        annual_rate: 10.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      regular_payments = schedule_data.select { |row| row[:payment_number].is_a?(Integer) }
      expect(regular_payments.length).to eq(24)
    end

    it 'fully amortizes a monthly loan' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :monthly,
        annual_rate: 10.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      final_payment = schedule_data.last
      expect(final_payment[:principal_balance]).to be < 0.02
    end

    it 'handles month-end edge cases' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-31',
        principal: 50_000.00,
        term_months: 3,
        frequency: :monthly,
        annual_rate: 10.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      dates = schedule_data.map { |row| row[:date] }
      # First payment: Feb doesn't have 31 days, should use last day of month
      expect(dates[0].month).to eq(2)
      expect(dates[0].day).to eq(28)
    end

    it 'spaces payments one month apart' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-03-15',
        principal: 50_000.00,
        term_months: 3,
        frequency: :monthly,
        annual_rate: 10.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      dates = schedule_data.map { |row| row[:date] }
      expect(dates[0]).to eq(Date.new(2026, 4, 15))
      expect(dates[1]).to eq(Date.new(2026, 5, 15))
      expect(dates[2]).to eq(Date.new(2026, 6, 15))
    end
  end

  describe 'monthly with bank_days_only' do
    it 'does not accumulate date drift over 12 months' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :monthly,
        annual_rate: 10.0,
        bank_days_only: true
      )
      data = schedule.schedule
      dates = data.map { |r| r[:date] }
      # Payment dates should stay near the 15th, never drift past the 20th
      dates.each do |d|
        expect(d.day).to be <= 20,
                         "Payment on #{d} drifted to day #{d.day}, expected <= 20"
      end
    end

    it 'all payment dates fall on business days' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :monthly,
        annual_rate: 10.0,
        bank_days_only: true
      )
      schedule.schedule.each do |row|
        expect(row[:date].saturday?).to be_falsey
        expect(row[:date].sunday?).to be_falsey
      end
    end
  end

  describe 'biweekly frequency' do
    it 'accepts biweekly frequency' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :biweekly,
        annual_rate: 10.0
      )
      expect(schedule.send(:total_payments)).to eq(26)
    end

    it 'fully amortizes a biweekly loan' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :biweekly,
        annual_rate: 10.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      final_payment = schedule_data.last
      expect(final_payment[:principal_balance]).to be < 0.02
    end

    it 'spaces payments 14 days apart' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        num_payments: 3,
        frequency: :biweekly,
        annual_rate: 10.0
      )
      schedule_data = schedule.send(:generate_schedule_data)
      dates = schedule_data.map { |row| row[:date] }
      expect(dates[1] - dates[0]).to eq(14)
    end
  end

  # Test public API

  describe 'public API' do
    let(:schedule) do
      Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :monthly,
        annual_rate: 10.0
      )
    end

    describe '#schedule' do
      it 'returns an array of payment hashes' do
        data = schedule.schedule
        expect(data).to be_an(Array)
        expect(data.first).to be_a(Hash)
        expect(data.first).to have_key(:payment_number)
        expect(data.first).to have_key(:date)
        expect(data.first).to have_key(:principal_payment)
      end

      it 'returns frozen data' do
        data = schedule.schedule
        expect(data).to be_frozen
      end

      it 'prevents mutation of individual payment hashes' do
        data = schedule.schedule
        expect { data.first[:principal_payment] = 999_999 }.to raise_error(FrozenError)
      end
    end

    describe '#summary' do
      it 'returns a hash with loan summary' do
        result = schedule.summary
        expect(result).to be_a(Hash)
        expect(result[:total_payments]).to eq(12)
        expect(result[:start_date]).to eq(Date.parse('2026-01-15'))
        expect(result[:principal]).to eq(100_000.00)
        expect(result[:total_interest]).to be > 0
        expect(result[:total_paid]).to be > 100_000.00
        expect(result[:end_date]).to be_a(Date)
      end
    end

    describe '#end_date' do
      it 'returns the date of the last payment' do
        expect(schedule.end_date).to be_a(Date)
        expect(schedule.end_date).to be > Date.parse('2026-01-15')
      end
    end

    describe '#total_interest' do
      it 'returns total interest paid' do
        expect(schedule.total_interest).to be > 0
        expect(schedule.total_interest).to be < 100_000.00
      end
    end

    describe '#total_paid' do
      it 'returns total amount paid including principal and interest' do
        expect(schedule.total_paid).to be > 100_000.00
      end
    end

    describe '#payment_amount' do
      it 'returns the regular payment amount' do
        expect(schedule.payment_amount).to be > 0
      end
    end
  end

  # Edge cases from triad review

  describe 'monthly December to January transition' do
    it 'advances correctly across year boundary' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-12-15',
        principal: 50_000.00,
        term_months: 3,
        frequency: :monthly,
        annual_rate: 10.0
      )
      dates = schedule.schedule.map { |row| row[:date] }
      expect(dates[0]).to eq(Date.new(2027, 1, 15))
      expect(dates[1]).to eq(Date.new(2027, 2, 15))
      expect(dates[2]).to eq(Date.new(2027, 3, 15))
    end
  end

  describe 'num_payments with new frequencies' do
    it 'works with monthly frequency' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        num_payments: 6,
        frequency: :monthly,
        annual_rate: 10.0
      )
      expect(schedule.schedule.length).to eq(6)
      expect(schedule.schedule.last[:principal_balance]).to be < 0.02
    end

    it 'works with biweekly frequency' do
      schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000.00,
        num_payments: 12,
        frequency: :biweekly,
        annual_rate: 10.0
      )
      regular = schedule.schedule.select { |r| r[:payment_number].is_a?(Integer) }
      expect(regular.length).to eq(12)
    end
  end

  describe 'input validation edge cases' do
    it 'raises error for zero num_payments' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000.00,
          num_payments: 0,
          frequency: :weekly,
          annual_rate: 10.0
        )
      end.to raise_error(ArgumentError, /num_payments must be a positive integer/)
    end

    it 'raises error for negative num_payments' do
      expect do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000.00,
          num_payments: -5,
          frequency: :weekly,
          annual_rate: 10.0
        )
      end.to raise_error(ArgumentError, /num_payments must be a positive integer/)
    end
  end

  describe 'term_months and num_payments equivalence' do
    it 'produces identical schedules for monthly frequency' do
      by_term = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        term_months: 12,
        frequency: :monthly,
        annual_rate: 10.0
      )
      by_count = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 100_000.00,
        num_payments: 12,
        frequency: :monthly,
        annual_rate: 10.0
      )
      expect(by_term.schedule.length).to eq(by_count.schedule.length)
      expect(by_term.total_interest).to be_within(0.01).of(by_count.total_interest)
    end
  end
end
