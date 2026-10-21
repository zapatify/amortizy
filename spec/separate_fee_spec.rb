# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Amortizy::AmortizationSchedule, 'separate fee payment' do
  def build(**overrides)
    described_class.new(start_date: '2026-01-15', principal: 12_000, annual_rate: 12.0, term_months: 12,
                        additional_fee: 500, additional_fee_treatment: :separate_payment, **overrides)
  end

  %i[monthly biweekly weekly daily].each do |frequency|
    context frequency.to_s do
      subject(:loan) { build(frequency: frequency) }

      let(:fee_row) { loan.schedule.find { |row| row[:payment_number].zero? } }
      let(:first_payment) { loan.schedule.find { |row| row[:payment_number] == 1 } }

      it 'puts the first regular payment one period after the fee' do
        expect(first_payment[:date]).to be > fee_row[:date]
        expect(first_payment[:days_in_period]).to be_positive
      end

      it 'charges interest from funding, including the fee period' do
        expect(first_payment[:days_in_period]).to eq((first_payment[:date] - loan.start_date).to_i)
        expect(loan.schedule.sum { |row| row[:days_in_period] }).to eq((loan.end_date - loan.start_date).to_i)
      end

      it 'still pays off with the regular payment' do
        expect(loan.schedule.last[:total_payment]).to be_within(0.01).of(loan.payment_amount)
        expect(loan.schedule.last[:principal_balance]).to eq(0)
      end
    end
  end

  describe 'with precomputed interest' do
    %i[monthly biweekly weekly daily].each do |frequency|
      it "charges #{frequency} interest for the fee period too" do
        with_fee = build(frequency: frequency, interest_method: :precomputed)
        without_fee = build(frequency: frequency, interest_method: :precomputed, additional_fee: 0)
        payments = with_fee.summary[:total_payments]
        expect(with_fee.total_interest).to be_within(0.01).of(without_fee.total_interest * (payments + 1) / payments)
      end

      it "never discloses a lower #{frequency} APR for adding a fee" do
        with_fee = Amortizy::Disclosure.new(build(frequency: frequency, interest_method: :precomputed))
        without_fee = Amortizy::Disclosure.new(build(frequency: frequency, interest_method: :precomputed,
                                                     additional_fee: 0))
        expect(with_fee.apr).to be >= without_fee.apr
      end
    end
  end

  it 'dates a monthly loan fee one month out and payment 1 a month after that' do
    dates = build(frequency: :monthly).schedule.first(3).map { |row| row[:date].to_s }
    expect(dates).to eq(%w[2026-02-15 2026-03-15 2026-04-15])
  end

  it 'clamps a month-end start to shorter months and keeps that day' do
    loan = build(frequency: :monthly, start_date: '2026-01-31')
    expect(loan.schedule.first(3).map { |row| row[:date].to_s }).to eq(%w[2026-02-28 2026-03-28 2026-04-28])
  end

  it 'moves bank-day payments off weekends with a positive first period' do
    loan = build(frequency: :monthly, bank_days_only: true, start_date: '2026-01-31')
    expect(loan.schedule.map { |row| row[:date] }).to all(satisfy { |date| !date.saturday? && !date.sunday? })
    first_two = loan.schedule.first(2).map { |row| row[:date].to_s }
    # Fee target Feb 28 is a Saturday (paid Mar 2); payment 1 targets Mar 28, also a Saturday.
    expect(first_two).to eq(%w[2026-03-02 2026-03-30])
  end
end
