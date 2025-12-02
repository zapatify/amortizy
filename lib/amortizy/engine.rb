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
    attr_reader :start_date, :principal, :term_months, :annual_rate, :frequency

    def initialize(start_date:, principal:, term_months:, annual_rate:, frequency:, origination_fee: 0,
                   additional_fee: 0, additional_fee_label: 'Additional Fee', additional_fee_treatment: :distributed, bank_days_only: false, interest_only_periods: 0, grace_period_days: 0, interest_method: :simple)
      @start_date = Date.parse(start_date.to_s)
      @principal = principal.to_f
      @term_months = term_months.to_i
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

      validate_term_months!
      validate_frequency!
      validate_fee_treatment!
      validate_interest_only_periods!
      validate_interest_method!
    end

    def generate(output: :console, csv_path: nil)
      case output
      when :console
        generate_console_output
      when :csv
        raise ArgumentError, 'csv_path required for CSV output' unless csv_path

        generate_csv_output(csv_path)
      else
        raise ArgumentError, 'Output must be :console or :csv'
      end
    end

    private

    def validate_frequency!
      return if %i[daily weekly].include?(@frequency)

      raise ArgumentError, 'Frequency must be :daily or :weekly'
    end

    def validate_term_months!
      return if [6, 9, 12, 15, 18].include?(@term_months)

      raise ArgumentError, 'Term must be 6, 9, 12, 15, or 18 months'
    end

    def validate_fee_treatment!
      return if %i[distributed add_to_principal separate_payment].include?(@additional_fee_treatment)

      raise ArgumentError, 'Additional fee treatment must be :distributed, :add_to_principal, or :separate_payment'
    end

    def validate_interest_only_periods!
      total_payments = calculate_total_payments
      return unless @interest_only_periods >= total_payments

      raise ArgumentError,
            "Interest-only periods (#{@interest_only_periods}) must be less than total payments (#{total_payments})"
    end

    def validate_interest_method!
      return if %i[simple precomputed].include?(@interest_method)

      raise ArgumentError, 'Interest method must be :simple or :precomputed'
    end

    def calculate_total_payments
      payment_schedule = {
        6 => { daily: 124, weekly: 27 },
        9 => { daily: 185, weekly: 39 },
        12 => { daily: 248, weekly: 53 },
        15 => { daily: 312, weekly: 65 },
        18 => { daily: 370, weekly: 79 }
      }

      payment_schedule[@term_months][@frequency]
    end

    def calculate_average_days_per_period
      return 1 if @frequency == :daily && !@bank_days_only
      return 7 if @frequency == :weekly && !@bank_days_only

      if @bank_days_only
        total_payments = calculate_total_payments
        current_date = first_payment_date
        total_days = 0
        sample_size = [30, total_payments].min

        (1..sample_size).each do |_i|
          next_date = next_payment_date(current_date)
          total_days += calculate_days_between(current_date, next_date)
          current_date = next_date
        end

        return total_days.to_f / sample_size
      end

      @frequency == :daily ? 1 : 7
    end

    def estimate_total_loan_days
      total_payments = calculate_total_payments
      avg_days_per_period = calculate_average_days_per_period
      total_payments * avg_days_per_period
    end

    def calculate_precomputed_total_interest
      principal_for_interest = initial_principal_with_origination
      total_days = estimate_total_loan_days
      principal_for_interest * @annual_rate * (total_days / 365.0)
    end

    def precomputed_interest_per_payment
      total_payments = calculate_total_payments
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
      total_payments = calculate_total_payments
      principal_payments = total_payments - @interest_only_periods

      if @interest_method == :precomputed
        principal_payment_portion = effective_principal / principal_payments
        interest_portion = precomputed_interest_per_payment

        if @additional_fee_treatment == :distributed
          principal_payment_portion + interest_portion + (@additional_fee / total_payments)
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
          base_payment + (@additional_fee / total_payments)
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
      case @frequency
      when :daily
        next_date = current_date + 1
      when :weekly
        next_date = current_date + 7
      end

      next_bank_day(next_date)
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
      total_payments = calculate_total_payments
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

      additional_fee_per_payment = @additional_fee_treatment == :distributed ? (@additional_fee / total_payments) : 0.0
      precomputed_interest = @interest_method == :precomputed ? precomputed_interest_per_payment : 0.0

      while payment_number < total_payments && balance > 0.01
        payment_number += 1
        payment_date = next_payment_date(previous_payment_date)
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
          principal_payment = balance if payment_number == total_payments
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

    def generate_console_output
      puts format_header
      puts '-' * 195

      generate_schedule_data.each do |row|
        if row[:payment_type] == 'Grace Period'
          puts format_grace_row(
            row[:payment_number],
            row[:date],
            row[:grace_interest_capitalized],
            row[:principal_balance],
            row[:days_in_period]
          )
        else
          puts format_row(
            row[:payment_number],
            row[:date],
            row[:principal_payment],
            row[:interest_payment],
            row[:additional_fee_payment],
            row[:total_payment],
            row[:principal_balance],
            row[:accrued_interest],
            row[:total_balance],
            row[:payment_type],
            row[:days_in_period]
          )
        end
      end

      print_summary
    end

    def generate_csv_output(csv_path)
      CSV.open(csv_path, 'w') do |csv|
        csv << [
          'Payment Number',
          'Date',
          'Days in Period',
          'Principal Payment',
          'Interest Payment',
          'Additional Fee Payment',
          'Total Payment',
          'Principal Balance Remaining',
          'Accrued Interest',
          'Total Balance',
          'Payment Type',
          'Grace Interest Capitalized'
        ]

        generate_schedule_data.each do |row|
          csv << [
            row[:payment_number],
            row[:date].strftime('%Y-%m-%d'),
            row[:days_in_period],
            format('%.2f', row[:principal_payment] || 0),
            format('%.2f', row[:interest_payment] || 0),
            format('%.2f', row[:additional_fee_payment] || 0),
            format('%.2f', row[:total_payment] || 0),
            format('%.2f', row[:principal_balance]),
            format('%.2f', row[:accrued_interest] || 0),
            format('%.2f', row[:total_balance]),
            row[:payment_type],
            row[:grace_interest_capitalized] ? format('%.2f', row[:grace_interest_capitalized]) : ''
          ]
        end
      end

      puts "CSV file generated: #{csv_path}"
    end

    def print_summary
      puts "\n#{'=' * 195}"
      puts 'LOAN SUMMARY'
      puts '=' * 195
      puts "Loan Start Date: #{@start_date.strftime('%Y-%m-%d')}"
      puts "First Payment Date: #{first_payment_date.strftime('%Y-%m-%d')}"
      puts "Term: #{@term_months} months"
      puts "Payment Frequency: #{@frequency.to_s.capitalize}"
      puts "Grace Period: #{@grace_period_days} days"

      if @grace_period_days.positive?
        puts "Grace Period Interest (Capitalized): $#{format('%.2f',
                                                             grace_period_interest)}"
      end

      puts "\nOriginal Principal: $#{format('%.2f', @principal)}"
      puts "Origination Fee: $#{format('%.2f', @origination_fee)} (added to principal)"
      puts "Additional Fee: $#{format('%.2f', @additional_fee)}"
      puts "#{@additional_fee_label} Treatment: #{@additional_fee_treatment.to_s.split('_').map(&:capitalize).join(' ')}"
      puts "Bank Days Only: #{@bank_days_only}"
      puts "Interest-Only Periods: #{@interest_only_periods}"
      puts "Interest Method: #{@interest_method.to_s.capitalize}"

      puts "\nPrincipal after Origination Fee: $#{format('%.2f', initial_principal_with_origination)}"

      if @grace_period_days.positive?
        puts "Principal after Grace Period (with capitalized interest): $#{format('%.2f',
                                                                                  initial_principal_with_origination + grace_period_interest)}"
      end

      case @additional_fee_treatment
      when :add_to_principal
        puts "Total Principal (with all fees): $#{format('%.2f', effective_principal)}"
      when :distributed
        puts "#{@additional_fee_label} per payment: $#{format('%.2f', @additional_fee / calculate_total_payments)}"
      when :separate_payment
        puts "#{@additional_fee_label} collected as separate payment"
      end

      if @interest_method == :precomputed
        puts "\nPrecomputed Interest Calculation:"
        puts "  Estimated Total Loan Days: #{format('%.0f', estimate_total_loan_days)}"
        puts "  Total Precomputed Interest: $#{format('%.2f', calculate_precomputed_total_interest)}"
        puts "  Interest per Payment: $#{format('%.2f', precomputed_interest_per_payment)}"
      end

      schedule_data = generate_schedule_data
      total_interest = schedule_data.sum { |row| row[:interest_payment] || 0 }
      total_additional_fees = schedule_data.sum { |row| row[:additional_fee_payment] || 0 }
      total_paid = effective_principal + total_interest + (@additional_fee_treatment == :separate_payment ? @additional_fee : 0)

      puts "\nTotal Interest Paid (during payments): $#{format('%.2f', total_interest)}"
      puts "Total Interest Including Grace Period: $#{format('%.2f', total_interest + grace_period_interest)}" if @grace_period_days.positive?
      puts "Total #{@additional_fee_label} Paid: $#{format('%.2f', total_additional_fees)}"
      puts "Total Amount Paid: $#{format('%.2f', total_paid)}"
      puts '=' * 195
    end

    def format_header
      format(
        '%-8s %-12s %-8s %15s %15s %18s %18s %20s %18s %18s %20s',
        'Payment',
        'Date',
        'Days',
        'Principal Pmt',
        'Interest Pmt',
        @additional_fee_label,
        'Total Payment',
        'Principal Balance',
        'Accrued Interest',
        'Total Balance',
        'Payment Type'
      )
    end

    def format_grace_row(_payment_num, date, grace_interest, principal_balance, days)
      format(
        '%-8s %-12s %-8d %15s %15s %18s %18s %20.2f %18s %18.2f %20s',
        'Grace',
        date.strftime('%Y-%m-%d'),
        days,
        '---',
        "+#{format('%.2f', grace_interest)}",
        '---',
        '0.00',
        principal_balance,
        '---',
        principal_balance,
        'Grace Period'
      )
    end

    def format_row(payment_num, date, principal_pmt, interest_pmt, additional_fee_pmt, total_pmt, principal_balance,
                   accrued_interest, total_balance, payment_type, days)
      format(
        '%-8s %-12s %-8d %15.2f %15.2f %18.2f %18.2f %20.2f %18.2f %18.2f %20s',
        payment_num.zero? ? 'Fee' : payment_num.to_s,
        date.strftime('%Y-%m-%d'),
        days,
        principal_pmt,
        interest_pmt,
        additional_fee_pmt,
        total_pmt,
        principal_balance,
        accrued_interest,
        total_balance,
        payment_type
      )
    end
  end
end
