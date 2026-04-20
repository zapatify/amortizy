# frozen_string_literal: true

module Amortizy
  class ConsoleFormatter
    def initialize(schedule_obj)
      @schedule_obj = schedule_obj
      @data = schedule_obj.schedule
    end

    def render
      puts header
      puts '-' * 195

      @data.each do |row|
        puts row[:payment_type] == 'Grace Period' ? grace_row(row) : payment_row(row)
      end

      print_summary
    end

    private

    def header
      format(
        '%-8s %-12s %-8s %15s %15s %18s %18s %20s %18s %18s %20s',
        'Payment', 'Date', 'Days', 'Principal Pmt', 'Interest Pmt',
        @schedule_obj.additional_fee_label, 'Total Payment', 'Principal Balance',
        'Accrued Interest', 'Total Balance', 'Payment Type'
      )
    end

    def grace_row(row)
      format(
        '%-8s %-12s %-8d %15s %15s %18s %18s %20.2f %18s %18.2f %20s',
        'Grace', row[:date].strftime('%Y-%m-%d'), row[:days_in_period],
        '---', "+#{format('%.2f', row[:grace_interest_capitalized])}",
        '---', '0.00', row[:principal_balance], '---',
        row[:principal_balance], 'Grace Period'
      )
    end

    def payment_row(row)
      label = row[:payment_number].is_a?(Integer) && row[:payment_number].zero? ? 'Fee' : row[:payment_number].to_s
      format(
        '%-8s %-12s %-8d %15.2f %15.2f %18.2f %18.2f %20.2f %18.2f %18.2f %20s',
        label, row[:date].strftime('%Y-%m-%d'), row[:days_in_period],
        row[:principal_payment], row[:interest_payment], row[:additional_fee_payment],
        row[:total_payment], row[:principal_balance], row[:accrued_interest],
        row[:total_balance], row[:payment_type]
      )
    end

    def print_summary
      summary = @schedule_obj.summary
      puts "\n#{'=' * 195}"
      puts 'LOAN SUMMARY'
      puts '=' * 195
      puts "Loan Start Date: #{summary[:start_date].strftime('%Y-%m-%d')}"
      puts "End Date: #{summary[:end_date].strftime('%Y-%m-%d')}"
      puts "Total Payments: #{summary[:total_payments]}"
      puts "Payment Frequency: #{summary[:frequency].to_s.capitalize}"
      puts "Annual Rate: #{format('%.2f', summary[:annual_rate])}%"
      puts "\nOriginal Principal: $#{format('%.2f', summary[:principal])}"
      puts "Regular Payment: $#{format('%.2f', summary[:payment_amount])}"
      puts "Total Interest Paid: $#{format('%.2f', summary[:total_interest])}"
      puts "Total Amount Paid: $#{format('%.2f', summary[:total_paid])}"
      puts '=' * 195
    end
  end
end
