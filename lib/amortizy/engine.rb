# frozen_string_literal: true

# Amortization Schedule Generator
#
# Generates comprehensive loan amortization schedules with support for:
# - Grace periods with capitalized interest
# - Interest-only payment periods
# - Origination and additional fees
# - Simple or precomputed interest methods
# - Bank business day calculations (Federal Reserve holidays)
# - Daily or weekly payment frequencies

require 'date'
require 'csv'
require 'holidays'

module Amortizy
  class AmortizationSchedule
    attr_reader :start_date, :principal, :term_months, :annual_rate, :frequency, :additional_fee_label

    def initialize(start_date:, principal:, annual_rate:, frequency:, term_months: nil, num_payments: nil,
                   origination_fee: 0, additional_fee: 0, additional_fee_label: 'Additional Fee',
                   additional_fee_treatment: :distributed, bank_days_only: false, interest_only_periods: 0,
                   grace_period_days: 0, interest_method: :simple)
      @start_date = Date.parse(start_date.to_s)
      @principal = principal.to_f
      @annual_rate = annual_rate.to_f / 100.0
      @frequency = frequency.to_sym
      @origination_fee = origination_fee.to_f
      @additional_fee = additional_fee.to_f
      @additional_fee_label = additional_fee_label.to_s
      @additional_fee_treatment = additional_fee_treatment.to_sym
      @bank_days_only = bank_days_only
      @interest_only_periods = interest_only_periods.to_i
      @grace_period_days = grace_period_days.to_i
      @interest_method = interest_method.to_sym

      validate_principal!
      validate_frequency!
      validate_term_input!(term_months, num_payments)
      validate_fee_treatment!
      validate_interest_only_periods!
      validate_interest_method!
    end

    def generate(output: :console, csv_path: nil)
      case output
      when :console
        ConsoleFormatter.new(self).render
      when :csv
        raise ArgumentError, 'csv_path required for CSV output' unless csv_path

        CsvFormatter.new(self).render(csv_path)
      else
        raise ArgumentError, 'Output must be :console or :csv'
      end
    end

    def schedule
      @schedule ||= generate_schedule_data.each(&:freeze).freeze
    end

    def summary
      schedule
      {
        start_date: @start_date,
        end_date: end_date,
        principal: @principal,
        total_payments: total_payments,
        frequency: @frequency,
        annual_rate: @annual_rate * 100.0,
        payment_amount: payment_amount,
        total_interest: total_interest,
        total_paid: total_paid
      }
    end

    def end_date
      schedule.last[:date]
    end

    def total_interest
      schedule.sum { |row| row[:interest_payment] || 0 }
    end

    def total_paid
      schedule.sum { |row| row[:total_payment] || 0 }
    end

    def payment_amount
      calculate_payment
    end

    private

    def validate_principal!
      raise ArgumentError, 'principal must be positive' unless @principal.positive?
    end

    def validate_frequency!
      return if %i[daily weekly monthly biweekly].include?(@frequency)

      raise ArgumentError, 'Frequency must be :daily, :weekly, :biweekly, or :monthly'
    end

    def validate_term_input!(term_months, num_payments)
      raise ArgumentError, 'Cannot specify both term_months and num_payments' if term_months && num_payments

      raise ArgumentError, 'Must specify either term_months or num_payments' if term_months.nil? && num_payments.nil?

      if term_months
        @term_months = term_months.to_i
        raise ArgumentError, 'term_months must be a positive integer' unless @term_months.positive?

        @num_payments = calculate_payments_from_term
      else
        @num_payments = num_payments.to_i
        raise ArgumentError, 'num_payments must be a positive integer' unless @num_payments.positive?

        @term_months = nil
      end
    end

    def validate_fee_treatment!
      return if %i[distributed add_to_principal separate_payment].include?(@additional_fee_treatment)

      raise ArgumentError, 'Additional fee treatment must be :distributed, :add_to_principal, or :separate_payment'
    end

    def validate_interest_only_periods!
      num = total_payments
      return unless @interest_only_periods >= num

      raise ArgumentError,
            "Interest-only periods (#{@interest_only_periods}) must be less than total payments (#{num})"
    end

    def validate_interest_method!
      return if %i[simple precomputed].include?(@interest_method)

      raise ArgumentError, 'Interest method must be :simple or :precomputed'
    end

    def total_payments
      @num_payments
    end

    def calculate_payments_from_term
      end_date = @start_date >> @term_months

      case @frequency
      when :monthly
        @term_months
      when :biweekly
        ((end_date - @start_date) / 14.0).round
      when :weekly
        ((end_date - @start_date) / 7.0).round
      when :daily
        if @bank_days_only
          count_business_days(@start_date, end_date)
        else
          (end_date - @start_date).to_i
        end
      end
    end

    def count_business_days(from_date, to_date)
      count = 0
      current = from_date
      while current < to_date
        count += 1 if bank_day?(current)
        current += 1
      end
      count
    end

    def calculate_average_days_per_period
      base_days = case @frequency
                  when :daily then 1
                  when :weekly then 7
                  when :biweekly then 14
                  when :monthly then 30.4375 # 365.25 / 12
                  end

      return base_days unless @bank_days_only

      num = total_payments
      current_date = first_payment_date
      total_days = 0
      sample_size = [30, num].min

      (1..sample_size).each do |_i|
        next_date = next_payment_date(current_date)
        total_days += calculate_days_between(current_date, next_date)
        current_date = next_date
      end

      total_days.to_f / sample_size
    end

    def estimate_total_loan_days
      num = total_payments
      avg_days_per_period = calculate_average_days_per_period
      num * avg_days_per_period
    end

    def calculate_precomputed_total_interest
      principal_for_interest = initial_principal_with_origination
      total_days = estimate_total_loan_days
      principal_for_interest * @annual_rate * (total_days / 365.0)
    end

    def precomputed_interest_per_payment
      calculate_precomputed_total_interest / total_payments
    end

    def initial_principal_with_origination
      @principal + @origination_fee
    end

    def grace_period_interest
      return 0.0 if @grace_period_days.zero?

      grace_rate = (@annual_rate / 365.0) * @grace_period_days
      initial_principal_with_origination * grace_rate
    end

    def effective_principal
      base_principal = initial_principal_with_origination + grace_period_interest

      case @additional_fee_treatment
      when :add_to_principal
        base_principal + @additional_fee
      else
        base_principal
      end
    end

    def first_payment_date
      if @grace_period_days.positive?
        grace_end_date = @start_date + @grace_period_days
        next_bank_day(grace_end_date)
      else
        @start_date
      end
    end

    def calculate_payment
      num = total_payments
      principal_payments = num - @interest_only_periods

      if @interest_method == :precomputed
        principal_payment_portion = effective_principal / principal_payments
        interest_portion = precomputed_interest_per_payment

        if @additional_fee_treatment == :distributed
          principal_payment_portion + interest_portion + (@additional_fee / num)
        else
          principal_payment_portion + interest_portion
        end
      else
        days_per_period = calculate_average_days_per_period
        period_rate = (@annual_rate / 365.0) * days_per_period

        base_payment = if period_rate.zero?
                         effective_principal / principal_payments
                       else
                         effective_principal * (period_rate * ((1 + period_rate)**principal_payments)) /
                           (((1 + period_rate)**principal_payments) - 1)
                       end

        if @additional_fee_treatment == :distributed
          base_payment + (@additional_fee / num)
        else
          base_payment
        end
      end
    end

    def federal_holiday?(date)
      holidays = Holidays.on(date, :federalreserve, :observed)
      !holidays.empty?
    end

    def bank_day?(date)
      return true unless @bank_days_only
      return false if date.saturday? || date.sunday?
      return false if federal_holiday?(date)

      true
    end

    def next_bank_day(date)
      return date unless @bank_days_only

      current = date
      current += 1 until bank_day?(current)
      current
    end

    def next_payment_date(current_date)
      next_date = case @frequency
                  when :daily
                    current_date + 1
                  when :weekly
                    current_date + 7
                  when :biweekly
                    current_date + 14
                  when :monthly
                    advance_by_month(current_date)
                  end

      next_bank_day(next_date)
    end

    def advance_by_month(date)
      target_year = date.month == 12 ? date.year + 1 : date.year
      target_month = date.month == 12 ? 1 : date.month + 1
      last_day = Date.new(target_year, target_month, -1).day
      target_day = [date.day, last_day].min
      Date.new(target_year, target_month, target_day)
    end

    def calculate_days_between(start_date, end_date)
      (end_date - start_date).to_i
    end

    def generate_schedule_data
      payment_amount = calculate_payment
      balance = effective_principal
      accrued_interest = 0.0
      payment_date = first_payment_date
      previous_payment_date = first_payment_date
      payment_number = 0
      num = total_payments
      schedule_data = []

      if @grace_period_days.positive?
        grace_interest = grace_period_interest
        schedule_data << {
          payment_number: 'Grace',
          date: first_payment_date,
          principal_payment: 0.0,
          interest_payment: 0.0,
          additional_fee_payment: 0.0,
          total_payment: 0.0,
          principal_balance: balance,
          accrued_interest: 0.0,
          total_balance: balance,
          payment_type: 'Grace Period',
          days_in_period: @grace_period_days,
          grace_interest_capitalized: grace_interest
        }
      end

      if @additional_fee_treatment == :separate_payment && @additional_fee.positive?
        payment_date = next_payment_date(payment_date)
        schedule_data << {
          payment_number: 0,
          date: payment_date,
          principal_payment: 0.0,
          interest_payment: 0.0,
          additional_fee_payment: @additional_fee,
          total_payment: @additional_fee,
          principal_balance: balance,
          accrued_interest: 0.0,
          total_balance: balance,
          payment_type: 'Additional Fee Payment',
          days_in_period: 0
        }
        previous_payment_date = payment_date
      end

      additional_fee_per_payment = @additional_fee_treatment == :distributed ? (@additional_fee / num) : 0.0
      precomputed_interest = @interest_method == :precomputed ? precomputed_interest_per_payment : 0.0

      # For monthly frequency, track the target date separately from the actual
      # payment date to prevent bank-day adjustments from compounding drift.
      monthly_target = @frequency == :monthly ? first_payment_date : nil

      while payment_number < num && balance > 0.01
        payment_number += 1

        if @frequency == :monthly && monthly_target
          monthly_target = advance_by_month(monthly_target)
          payment_date = next_bank_day(monthly_target)
        else
          payment_date = next_payment_date(previous_payment_date)
        end

        days_in_period = calculate_days_between(previous_payment_date, payment_date)

        if @interest_method == :precomputed
          interest_payment = precomputed_interest
        else
          period_rate = (@annual_rate / 365.0) * days_in_period
          interest_payment = balance * period_rate
        end

        accrued_interest += interest_payment
        is_interest_only = payment_number <= @interest_only_periods

        if is_interest_only
          principal_payment = 0.0
          payment_type = 'Interest Only'
        else
          principal_payment = [payment_amount - interest_payment - additional_fee_per_payment, balance].min
          principal_payment = balance if payment_number == num
          payment_type = 'Regular Payment'
        end

        total_payment = principal_payment + interest_payment + additional_fee_per_payment
        balance -= principal_payment
        balance = 0 if balance < 0.01
        total_balance = balance + accrued_interest

        schedule_data << {
          payment_number: payment_number,
          date: payment_date,
          principal_payment: principal_payment,
          interest_payment: interest_payment,
          additional_fee_payment: additional_fee_per_payment,
          total_payment: total_payment,
          principal_balance: balance,
          accrued_interest: accrued_interest,
          total_balance: total_balance,
          payment_type: payment_type,
          days_in_period: days_in_period
        }

        accrued_interest = 0.0
        previous_payment_date = payment_date
      end

      schedule_data
    end
  end
end
