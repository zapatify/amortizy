# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Amortizy::AmortizationSchedule, 'payment sizing' do
  def regular_rows(loan)
    loan.schedule.select { |row| row[:payment_number].is_a?(Integer) && row[:payment_number].positive? }
  end

  { monthly: 360, biweekly: 60, weekly: 60, daily: 12 }.each do |frequency, term|
    [0, 6.0, 18.0, 36.0].each do |rate|
      [false, true].each do |bank_days|
        context "#{frequency}, #{rate}%, #{term} months, bank_days_only: #{bank_days}" do
          subject(:loan) do
            described_class.new(start_date: '2026-01-15', principal: 1_000_000, annual_rate: rate,
                                frequency: frequency, term_months: term, bank_days_only: bank_days)
          end

          it 'makes every scheduled payment' do
            expect(regular_rows(loan).length).to eq(loan.summary[:total_payments])
          end

          it 'makes the final payment equal to the regular payment' do
            expect(loan.schedule.last[:total_payment]).to be_within(0.01).of(loan.payment_amount)
            expect(loan.schedule.last[:principal_balance]).to eq(0)
          end
        end
      end
    end
  end

  [
    { grace_period_days: 10 },
    { interest_only_periods: 12 },
    { origination_fee: 5_000, additional_fee: 2_500, additional_fee_treatment: :distributed },
    { additional_fee: 2_500, additional_fee_treatment: :add_to_principal },
    { additional_fee: 2_500, additional_fee_treatment: :separate_payment },
    { grace_period_days: 3, interest_only_periods: 6, bank_days_only: true }
  ].each do |options|
    context "monthly 12%, 120 months with #{options}" do
      subject(:loan) do
        described_class.new(start_date: '2026-01-15', principal: 250_000, annual_rate: 12.0,
                            frequency: :monthly, term_months: 120, **options)
      end

      it 'makes the final payment equal to the regular payment' do
        expect(regular_rows(loan).length).to eq(120)
        expect(loan.schedule.last[:total_payment]).to be_within(0.01).of(loan.payment_amount)
        expect(loan.schedule.last[:principal_balance]).to eq(0)
      end
    end
  end

  it 'matches the textbook payment when every period has the same length' do
    loan = described_class.new(start_date: '2026-01-15', principal: 100_000, annual_rate: 10.0,
                               frequency: :weekly, num_payments: 52)
    rate = (0.10 / 365.0) * 7
    expected = 100_000 * rate * ((1 + rate)**52) / (((1 + rate)**52) - 1)
    expect(loan.payment_amount).to be_within(0.000001).of(expected)
  end
end
