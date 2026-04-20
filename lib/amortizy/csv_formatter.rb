# frozen_string_literal: true

require 'csv'

module Amortizy
  class CsvFormatter
    HEADERS = [
      'Payment Number', 'Date', 'Days in Period', 'Principal Payment',
      'Interest Payment', 'Additional Fee Payment', 'Total Payment',
      'Principal Balance Remaining', 'Accrued Interest', 'Total Balance',
      'Payment Type', 'Grace Interest Capitalized'
    ].freeze

    def initialize(schedule_obj)
      @data = schedule_obj.schedule
    end

    def render(csv_path)
      CSV.open(csv_path, 'w') do |csv|
        csv << HEADERS

        @data.each do |row|
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
  end
end
