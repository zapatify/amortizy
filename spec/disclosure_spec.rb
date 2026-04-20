# frozen_string_literal: true

require 'rspec'
require 'date'
require 'spec_helper'

RSpec.describe Amortizy::Disclosure do
  # Standard test loan: $50,000, 12% annual rate, 36 months, monthly payments
  # Origination fee: $500 (prepaid finance charge)
  # Additional fee: $250 (distributed across payments)
  let(:schedule) do
    Amortizy::AmortizationSchedule.new(
      start_date: '2026-01-15',
      principal: 50_000,
      annual_rate: 12.0,
      frequency: :monthly,
      term_months: 36,
      origination_fee: 500,
      additional_fee: 250,
      additional_fee_label: 'Processing Fee',
      additional_fee_treatment: :distributed
    )
  end

  let(:disclosure) { Amortizy::Disclosure.new(schedule) }

  # ---- Phase 1: Instantiation ----

  describe 'initialization' do
    it 'accepts an AmortizationSchedule' do
      expect(disclosure).to be_a(Amortizy::Disclosure)
    end

    it 'raises ArgumentError for non-schedule input' do
      expect { Amortizy::Disclosure.new('not a schedule') }
        .to raise_error(ArgumentError, /must be an Amortizy::AmortizationSchedule/)
    end

    it 'accepts optional third_party_payments' do
      d = Amortizy::Disclosure.new(schedule, third_party_payments: 5_000)
      expect(d.recipient_funds).to be < d.amount_financed
    end

    it 'accepts optional prepayment_penalty_max' do
      d = Amortizy::Disclosure.new(schedule, prepayment_penalty_max: 1_200)
      expect(d.prepayment[:max_non_interest_finance_charge]).to eq(1_200.0)
    end

    it 'accepts optional additional_prepayment_fees' do
      fees = [{ amount: 150.0, description: 'Early termination fee' }]
      d = Amortizy::Disclosure.new(schedule, additional_prepayment_fees: fees)
      expect(d.prepayment[:additional_fees]).to eq(fees)
    end

    it 'defaults optional params to zero/empty' do
      expect(disclosure.recipient_funds).to eq(disclosure.amount_financed)
      expect(disclosure.prepayment[:max_non_interest_finance_charge]).to be_nil
      expect(disclosure.prepayment[:additional_fees]).to be_empty
    end
  end

  # ---- Phase 2: Simple Computed Properties ----

  describe '#finance_charge' do
    it 'satisfies the Reg Z identity: total_payment = amount_financed + finance_charge' do
      identity = disclosure.amount_financed + disclosure.finance_charge
      expect(identity).to be_within(0.01).of(disclosure.total_payment_amount)
    end

    it 'is always positive for a loan with interest' do
      expect(disclosure.finance_charge).to be > 0
    end

    it 'exceeds total interest when fees are present' do
      expect(disclosure.finance_charge).to be > schedule.total_interest
    end

    context 'identity holds across all fee treatments' do
      %i[distributed add_to_principal separate_payment].each do |treatment|
        it "holds for #{treatment} fee treatment" do
          s = Amortizy::AmortizationSchedule.new(
            start_date: '2026-01-15', principal: 50_000,
            annual_rate: 12.0, frequency: :monthly, term_months: 36,
            origination_fee: 500, additional_fee: 250,
            additional_fee_treatment: treatment
          )
          d = Amortizy::Disclosure.new(s)
          gap = d.total_payment_amount - (d.amount_financed + d.finance_charge)
          expect(gap.abs).to(be < 0.01,
                             "Identity gap of #{gap} for #{treatment}")
        end
      end
    end
  end

  describe '#amount_financed' do
    context 'with distributed additional fee' do
      it 'equals principal minus origination fee' do
        # Amount financed = principal - prepaid finance charges (origination fee)
        # Distributed additional fee is NOT added to amount financed
        expect(disclosure.amount_financed).to be_within(0.01).of(49_500.00)
      end
    end

    context 'with additional fee added to principal' do
      let(:schedule_add_to_principal) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 36,
          origination_fee: 500,
          additional_fee: 250,
          additional_fee_treatment: :add_to_principal
        )
      end

      it 'includes additional fee in amount financed' do
        d = Amortizy::Disclosure.new(schedule_add_to_principal)
        # principal + additional_fee - origination_fee = 50000 + 250 - 500 = 49750
        expect(d.amount_financed).to be_within(0.01).of(49_750.00)
      end
    end

    context 'with separate payment additional fee' do
      let(:schedule_separate) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 36,
          origination_fee: 500,
          additional_fee: 250,
          additional_fee_treatment: :separate_payment
        )
      end

      it 'does not include separate payment fee in amount financed' do
        d = Amortizy::Disclosure.new(schedule_separate)
        # principal - origination_fee = 50000 - 500 = 49500
        expect(d.amount_financed).to be_within(0.01).of(49_500.00)
      end
    end
  end

  describe '#total_payment_amount' do
    it 'equals the schedule total_paid' do
      expect(disclosure.total_payment_amount).to be_within(0.01).of(schedule.total_paid)
    end
  end

  describe '#recipient_funds' do
    it 'equals amount_financed when no third-party payments' do
      expect(disclosure.recipient_funds).to eq(disclosure.amount_financed)
    end

    it 'deducts third-party payments' do
      d = Amortizy::Disclosure.new(schedule, third_party_payments: 10_000)
      expect(d.recipient_funds).to be_within(0.01).of(disclosure.amount_financed - 10_000)
    end

    it 'returns negative when third_party_payments exceed amount_financed' do
      d = Amortizy::Disclosure.new(schedule, third_party_payments: 100_000)
      expect(d.recipient_funds).to be < 0
    end
  end

  describe '#term_days' do
    it 'returns the number of days from start to last payment' do
      expected_days = (schedule.end_date - schedule.start_date).to_i
      expect(disclosure.term_days).to eq(expected_days)
    end

    it 'is positive' do
      expect(disclosure.term_days).to be > 0
    end
  end

  describe '#term_display' do
    context 'when term is one year or less' do
      let(:short_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 10_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 6
        )
      end

      it 'displays in days' do
        d = Amortizy::Disclosure.new(short_schedule)
        expect(d.term_display).to match(/\d+ days/)
      end
    end

    context 'when term is greater than one year' do
      it 'displays in years and months' do
        expect(disclosure.term_display).to match(/\d+ years?, \d+\.\d{2} months?/)
      end
    end
  end

  describe '#average_monthly_cost' do
    it 'returns nil for monthly frequency' do
      expect(disclosure.average_monthly_cost).to be_nil
    end

    context 'with weekly frequency' do
      let(:weekly_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :weekly,
          term_months: 12,
          origination_fee: 500
        )
      end

      it 'calculates total payments divided by months' do
        d = Amortizy::Disclosure.new(weekly_schedule)
        expected = weekly_schedule.total_paid / (d.term_days / 30.4)
        expect(d.average_monthly_cost).to be_within(0.01).of(expected)
      end

      it 'is positive' do
        d = Amortizy::Disclosure.new(weekly_schedule)
        expect(d.average_monthly_cost).to be > 0
      end
    end

    context 'with biweekly frequency' do
      let(:biweekly_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :biweekly,
          term_months: 24
        )
      end

      it 'returns a value for non-monthly frequency' do
        d = Amortizy::Disclosure.new(biweekly_schedule)
        expect(d.average_monthly_cost).not_to be_nil
        expect(d.average_monthly_cost).to be > 0
      end
    end
  end

  # ---- Phase 3: APR ----

  describe '#apr' do
    it 'returns a positive rate for a standard loan' do
      expect(disclosure.apr).to be > 0
    end

    it 'is higher than the nominal annual rate when fees are present' do
      # APR should exceed the stated rate because it incorporates fees
      expect(disclosure.apr).to be > 12.0
    end

    it 'equals the nominal rate (approximately) when there are no fees' do
      no_fee_schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000,
        annual_rate: 12.0,
        frequency: :monthly,
        term_months: 36
      )
      d = Amortizy::Disclosure.new(no_fee_schedule)
      # With no fees, APR should be very close to the nominal rate
      expect(d.apr).to be_within(0.5).of(12.0)
    end

    it 'is rounded to the nearest 10 basis points' do
      apr_value = disclosure.apr
      # A value at 10 basis points is a multiple of 0.1
      expect(apr_value * 10 % 1).to(eq(0),
                                    "Expected APR #{apr_value} to be a multiple of 0.10")
    end

    it 'meets Reg Z tolerance of 1/8 of 1 percentage point' do
      # For a no-fee loan, the exact APR equals the nominal rate.
      # The disclosed APR (rounded to 10 bps) must be within 0.125 of 12.0.
      no_fee_schedule = Amortizy::AmortizationSchedule.new(
        start_date: '2026-01-15',
        principal: 50_000,
        annual_rate: 12.0,
        frequency: :monthly,
        term_months: 36
      )
      d = Amortizy::Disclosure.new(no_fee_schedule)
      expect(d.apr).to be_within(0.125).of(12.0)
    end

    context 'against a known loan with fees' do
      let(:known_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 36,
          origination_fee: 500
        )
      end

      it 'computes APR above nominal rate due to origination fee' do
        d = Amortizy::Disclosure.new(known_schedule)
        # $500 origination fee on $50K/12%/36mo pushes APR above 12%
        expect(d.apr).to be > 12.0
        expect(d.apr).to be_within(1.0).of(12.5)
      end
    end

    context 'with zero interest rate' do
      let(:zero_rate_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 10_000,
          annual_rate: 0.01, # near-zero to avoid division issues
          frequency: :monthly,
          term_months: 12,
          origination_fee: 500
        )
      end

      it 'reflects fees in APR even without meaningful interest' do
        d = Amortizy::Disclosure.new(zero_rate_schedule)
        expect(d.apr).to be > 0
      end
    end

    context 'with grace period' do
      let(:no_grace_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 36,
          origination_fee: 500
        )
      end

      let(:grace_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 36,
          origination_fee: 500,
          grace_period_days: 30
        )
      end

      it 'accounts for grace period in the cash flow timing' do
        d_no_grace = Amortizy::Disclosure.new(no_grace_schedule)
        d_with_grace = Amortizy::Disclosure.new(grace_schedule)
        # Grace period capitalizes interest, increasing effective principal
        # and total payments, which affects the APR calculation inputs
        expect(d_with_grace.finance_charge).not_to eq(d_no_grace.finance_charge)
        expect(d_with_grace.apr).to be > 0
      end
    end

    context 'with interest-only periods' do
      let(:io_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 50_000,
          annual_rate: 12.0,
          frequency: :monthly,
          term_months: 36,
          origination_fee: 500,
          interest_only_periods: 6
        )
      end

      it 'handles mixed payment types' do
        d = Amortizy::Disclosure.new(io_schedule)
        expect(d.apr).to be_a(Float)
        expect(d.apr).to be > 0
      end
    end

    context 'with short term loan' do
      let(:short_schedule) do
        Amortizy::AmortizationSchedule.new(
          start_date: '2026-01-15',
          principal: 5_000,
          annual_rate: 18.0,
          frequency: :weekly,
          num_payments: 4,
          origination_fee: 100
        )
      end

      it 'handles very short terms' do
        d = Amortizy::Disclosure.new(short_schedule)
        expect(d.apr).to be_a(Float)
        expect(d.apr).to be > 0
      end
    end
  end

  # ---- Phase 4: Prepayment ----

  describe '#prepayment' do
    it 'returns a hash' do
      expect(disclosure.prepayment).to be_a(Hash)
    end

    context 'with no prepayment penalties' do
      it 'indicates no non-interest charges' do
        expect(disclosure.prepayment[:has_non_interest_charges]).to be false
        expect(disclosure.prepayment[:max_non_interest_finance_charge]).to be_nil
      end

      it 'indicates no additional fees' do
        expect(disclosure.prepayment[:has_additional_fees]).to be false
        expect(disclosure.prepayment[:additional_fees]).to be_empty
      end
    end

    context 'with prepayment penalty max' do
      let(:disclosure_with_penalty) do
        Amortizy::Disclosure.new(schedule, prepayment_penalty_max: 1_200)
      end

      it 'indicates non-interest charges exist' do
        expect(disclosure_with_penalty.prepayment[:has_non_interest_charges]).to be true
        expect(disclosure_with_penalty.prepayment[:max_non_interest_finance_charge]).to eq(1_200.0)
      end
    end

    context 'with additional prepayment fees' do
      let(:disclosure_with_fees) do
        fees = [{ amount: 250.0, description: 'Early termination fee' }]
        Amortizy::Disclosure.new(schedule, additional_prepayment_fees: fees)
      end

      it 'indicates additional fees exist' do
        expect(disclosure_with_fees.prepayment[:has_additional_fees]).to be true
        expect(disclosure_with_fees.prepayment[:additional_fees].length).to eq(1)
      end
    end
  end

  # ---- Phase 5: Output Methods ----

  describe '#to_h' do
    subject(:hash) { disclosure.to_h }

    it 'includes all required keys' do
      expected_keys = %i[
        amount_financed apr finance_charge total_payment_amount
        payment_amount payment_frequency term_days term_display
        average_monthly_cost recipient_funds prepayment
      ]
      expect(hash.keys).to match_array(expected_keys)
    end

    it 'has Float values for monetary fields' do
      %i[amount_financed apr finance_charge total_payment_amount
         payment_amount recipient_funds].each do |key|
        expect(hash[key]).to be_a(Float), "Expected #{key} to be Float, got #{hash[key].class}"
      end
    end

    it 'rounds monetary values to 2 decimal places' do
      %i[amount_financed finance_charge total_payment_amount
         payment_amount recipient_funds].each do |key|
        value = hash[key]
        expect(value).to eq(value.round(2)), "Expected #{key} to be rounded to 2 decimals"
      end
    end
  end

  describe '#to_labeled_h' do
    subject(:labeled) { disclosure.to_labeled_h }

    it 'includes label and value for each element' do
      labeled.each do |key, entry|
        next if key == :prepayment # prepayment has nested structure

        expect(entry).to have_key(:label), "Expected #{key} to have :label"
        expect(entry).to have_key(:value), "Expected #{key} to have :value"
      end
    end

    it 'uses regulation-correct label for APR' do
      expect(labeled[:apr][:label]).to eq('Annual Percentage Rate (APR)')
    end

    it 'uses regulation-correct label for finance charge' do
      expect(labeled[:finance_charge][:label]).to eq('Finance Charge')
    end

    it 'uses regulation-correct label for funding provided' do
      expect(labeled[:amount_financed][:label]).to eq('Funding Provided')
    end

    it 'uses regulation-correct label for total payment amount' do
      expect(labeled[:total_payment_amount][:label]).to eq('Total Payment Amount')
    end
  end
end
