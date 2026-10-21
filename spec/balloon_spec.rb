# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Amortizy::AmortizationSchedule, 'balloon payments' do
  def build(**overrides)
    Amortizy::AmortizationSchedule.new(
      start_date: '2026-01-15',
      principal: 100_000,
      annual_rate: 6.0,
      frequency: :monthly,
      term_months: 60,
      **overrides
    )
  end

  describe 'with no interest' do
    subject(:loan) do
      build(principal: 12_000, annual_rate: 0, term_months: 12, balloon_amount: 6_000)
    end

    it 'amortizes only the principal above the balloon' do
      expect(loan.payment_amount).to eq(500.0)
    end

    it 'charges the regular payment on every payment but the last' do
      regular = loan.schedule[0..-2]
      expect(regular.map { |row| row[:total_payment] }).to all(be_within(0.001).of(500.0))
      expect(regular.map { |row| row[:payment_type] }).to all(eq('Regular Payment'))
    end

    it 'adds the balloon to the final payment' do
      last = loan.schedule.last
      expect(last[:total_payment]).to be_within(0.001).of(6_500.0)
      expect(last[:principal_payment]).to be_within(0.001).of(6_500.0)
      expect(last[:principal_balance]).to eq(0)
      expect(last[:payment_type]).to eq('Balloon Payment')
    end
  end

  describe 'with simple interest' do
    subject(:loan) { build(balloon_amount: 40_000) }

    let(:no_balloon) { build }

    it 'matches the annuity formula with a future value when periods are equal' do
      weekly = build(frequency: :weekly, term_months: nil, num_payments: 52, balloon_amount: 40_000)
      rate = (0.06 / 365.0) * 7
      growth = (1 + rate)**52
      expected = rate * ((100_000 * growth) - 40_000) / (growth - 1)
      expect(weekly.payment_amount).to be_within(0.000001).of(expected)
    end

    it 'lowers the regular payment' do
      expect(loan.payment_amount).to be < no_balloon.payment_amount
    end

    it 'makes the final payment the regular payment plus the balloon' do
      expect(loan.schedule.last[:total_payment]).to be_within(0.01).of(loan.payment_amount + 40_000)
    end

    it 'repays all principal by the end' do
      expect(loan.schedule.sum { |row| row[:principal_payment] }).to be_within(0.01).of(100_000)
      expect(loan.schedule.last[:principal_balance]).to eq(0)
    end

    it 'keeps the payment count' do
      expect(loan.schedule.length).to eq(60)
    end

    it 'makes the final payment the balloon plus that period' do
      last = loan.schedule.last
      expect(last[:total_payment]).to be_within(0.01).of(loan.schedule[-2][:principal_balance] + last[:interest_payment])
    end

    it 'costs more interest than the fully amortizing loan' do
      expect(loan.total_interest).to be > no_balloon.total_interest
    end
  end

  describe 'across long terms, high rates and bank days' do
    [
      { annual_rate: 12.0, term_months: 84, bank_days_only: true },
      { annual_rate: 12.0, term_months: 360, bank_days_only: true },
      { annual_rate: 18.0, term_months: 360 },
      { annual_rate: 24.0, term_months: 240, frequency: :biweekly },
      { annual_rate: 7.25, term_months: 12, frequency: :daily, bank_days_only: true },
      { annual_rate: 9.0, term_months: 120, grace_period_days: 10, interest_only_periods: 6 },
      { annual_rate: 9.0, term_months: 120, additional_fee: 2_500, additional_fee_treatment: :separate_payment }
    ].each do |options|
      context options.to_s do
        subject(:loan) { build(principal: 1_000_000, balloon_amount: 700_000, **options) }

        it 'makes every payment and ends with the regular payment plus the balloon' do
          regular = loan.schedule.count { |row| row[:payment_number].is_a?(Integer) && row[:payment_number].positive? }
          expect(regular).to eq(loan.summary[:total_payments])
          expect(loan.schedule.last[:payment_type]).to eq('Balloon Payment')
          expect(loan.schedule.last[:total_payment]).to be_within(0.01).of(loan.payment_amount + 700_000)
          expect(loan.schedule.last[:principal_balance]).to eq(0)
        end
      end
    end

    it 'still pays off exactly when the balloon is close to the principal' do
      loan = build(principal: 500_000, annual_rate: 7.25, frequency: :daily, term_months: 12,
                   bank_days_only: true, balloon_amount: 490_000)
      expect(loan.schedule.count { |row| row[:principal_payment].negative? }).to be_positive
      expect(loan.schedule.last[:total_payment]).to be_within(0.01).of(loan.payment_amount + 490_000)
    end
  end

  describe 'with precomputed interest' do
    subject(:loan) do
      build(principal: 12_000, term_months: 12, balloon_amount: 6_000, interest_method: :precomputed)
    end

    it 'spreads only the principal above the balloon across the payments' do
      interest_per_payment = loan.schedule.first[:interest_payment]
      expect(loan.payment_amount).to be_within(0.001).of(500.0 + interest_per_payment)
    end

    it 'adds the balloon to the final payment' do
      expect(loan.schedule.last[:principal_payment]).to be_within(0.01).of(6_500.0)
      expect(loan.schedule.last[:principal_balance]).to eq(0)
    end
  end

  describe 'with interest-only periods' do
    subject(:loan) do
      build(principal: 12_000, annual_rate: 0, term_months: 12, interest_only_periods: 4, balloon_amount: 4_000)
    end

    it 'amortizes down to the balloon over the remaining payments' do
      expect(loan.payment_amount).to eq(1_000.0)
      expect(loan.schedule.first(4).map { |row| row[:payment_type] }).to all(eq('Interest Only'))
      expect(loan.schedule.last[:total_payment]).to be_within(0.001).of(5_000.0)
    end
  end

  describe 'with num_payments and weekly payments' do
    subject(:loan) do
      build(principal: 5_200, annual_rate: 0, frequency: :weekly, term_months: nil, num_payments: 52,
            balloon_amount: 2_600)
    end

    it 'puts the balloon on the last payment' do
      expect(loan.payment_amount).to eq(50.0)
      expect(loan.schedule.last[:total_payment]).to be_within(0.001).of(2_650.0)
    end
  end

  describe 'with no balloon' do
    it 'defaults to zero and leaves the schedule unchanged' do
      loan = build
      expect(loan.balloon_amount).to eq(0.0)
      expect(loan.schedule).to eq(build(balloon_amount: 0).schedule)
      expect(loan.schedule.last[:payment_type]).to eq('Regular Payment')
    end
  end

  describe '#summary' do
    it 'reports the balloon amount' do
      expect(build(balloon_amount: 40_000).summary[:balloon_amount]).to eq(40_000.0)
      expect(build.summary[:balloon_amount]).to eq(0.0)
    end
  end

  describe 'validation' do
    it 'rejects text that is not a number' do
      expect { build(balloon_amount: '$350,000') }.to raise_error(ArgumentError, /balloon_amount must be a number/)
      expect { build(balloon_amount: 'abc') }.to raise_error(ArgumentError, /balloon_amount must be a number/)
    end

    it 'rejects NaN and infinity' do
      expect { build(balloon_amount: Float::NAN) }.to raise_error(ArgumentError, /must be a number/)
      expect { build(balloon_amount: Float::INFINITY) }.to raise_error(ArgumentError, /must be a number/)
    end

    it 'treats nil as no balloon' do
      expect(build(balloon_amount: nil).balloon_amount).to eq(0.0)
    end

    it 'accepts numeric strings' do
      expect(build(balloon_amount: '40000.50').balloon_amount).to eq(40_000.5)
    end

    it 'rejects a negative balloon' do
      expect { build(balloon_amount: -1) }.to raise_error(ArgumentError, /balloon_amount must not be negative/)
    end

    it 'rejects a balloon equal to the amount being amortized' do
      expect { build(balloon_amount: 100_000) }
        .to raise_error(ArgumentError, /balloon_amount must be less than the amortized balance \(100000.00\)/)
    end

    it 'measures the limit against principal plus fees' do
      expect { build(origination_fee: 1_000, balloon_amount: 100_500) }.not_to raise_error
      expect { build(origination_fee: 1_000, balloon_amount: 101_000) }.to raise_error(ArgumentError, /101000.00/)
    end
  end

  describe 'disclosure' do
    it 'keeps the APR at the note rate when there are no fees' do
      disclosure = Amortizy::Disclosure.new(build(annual_rate: 12.0, balloon_amount: 40_000))
      expect(disclosure.apr).to be_within(0.125).of(12.0)
    end

    it 'includes the balloon in the total of payments' do
      disclosure = Amortizy::Disclosure.new(build(balloon_amount: 40_000))
      expect(disclosure.total_payment_amount).to be > 40_000 + (59 * disclosure.payment_amount)
    end
  end
end
