# frozen_string_literal: true

# Commercial Financing Disclosure Calculator
#
# Computes disclosure data elements for closed-end commercial loan transactions
# per California SB 1235 (Title 10, Chapter 3, Subchapter 3). Values are
# jurisdiction-agnostic — the gem computes numbers, not documents.
#
# APR is calculated using the actuarial method per Appendix J of Regulation Z
# (12 CFR Part 1026), as required by section 940 of the regulation.
#
# Key assumption: the origination fee is treated as a prepaid finance charge
# (deducted from amount financed, included in finance charge).
#
# Regulatory references:
#   - Section 910: Closed-end transaction disclosure contents
#   - Section 940: APR calculation method
#   - Section 943: Finance charge definition
#   - Section 900(a)(1)(B): Amount financed for closed-end transactions
#   - Section 900(a)(26): Recipient funds
#   - Section 901(a)(4): Term display formatting
#   - Section 901(a)(5): APR rounding (nearest 10 basis points)
#   - Section 955: APR tolerance (1/8 of 1 percentage point)

module Amortizy
  class Disclosure
    APR_MAX_ITERATIONS = 100
    APR_CONVERGENCE_TOLERANCE = 1e-8
    APR_REG_Z_TOLERANCE = 0.00125 # 1/8 of 1 percentage point

    def initialize(schedule, third_party_payments: 0, prepayment_penalty_max: 0,
                   additional_prepayment_fees: [])
      raise ArgumentError, 'First argument must be an Amortizy::AmortizationSchedule' unless schedule.is_a?(Amortizy::AmortizationSchedule)

      @schedule = schedule
      @third_party_payments = third_party_payments.to_f
      @prepayment_penalty_max = prepayment_penalty_max.to_f
      @additional_prepayment_fees = additional_prepayment_fees
    end

    # --- Finance Charge (§943) ---
    # Total dollar cost of the financing. Derived from the Reg Z identity:
    #   Finance Charge = Total Payment Amount - Amount Financed
    # This ensures the three core disclosure values are always consistent.

    def finance_charge
      @finance_charge ||= total_payment_amount - amount_financed
    end

    # --- Amount Financed (§900(a)(1)(B)) ---
    # Principal + financed amounts - prepaid finance charges (origination fee).

    def amount_financed
      @amount_financed ||= begin
        base = principal - origination_fee
        base += additional_fee if fee_treatment == :add_to_principal
        base
      end
    end

    # --- Total Payment Amount (§910(a)(5)) ---

    def total_payment_amount
      @schedule.total_paid
    end

    # --- Payment Amount ---

    def payment_amount
      @schedule.payment_amount
    end

    # --- Payment Frequency ---

    def payment_frequency
      @schedule.frequency
    end

    # --- Recipient Funds (§900(a)(26)) ---
    # Net amount given directly to the borrower.

    def recipient_funds
      amount_financed - @third_party_payments
    end

    # --- Term (§901(a)(4)) ---

    def term_days
      @term_days ||= (@schedule.end_date - disbursement_date).to_i
    end

    def term_display
      if term_days <= 365
        "#{term_days} days"
      else
        years = term_days / 365
        remaining_days = term_days % 365
        months = (remaining_days / 30.4).round(2)
        year_label = years == 1 ? 'year' : 'years'
        month_label = (months - 1.0).abs < 0.005 ? 'month' : 'months'
        format('%d %s, %.2f %s', years, year_label, months, month_label)
      end
    end

    # --- Average Monthly Cost (§910(a)(12)) ---
    # Only for non-monthly payment frequencies.

    def average_monthly_cost
      return nil if @schedule.frequency == :monthly
      return nil if term_days <= 0

      total_payment_amount / (term_days / 30.4)
    end

    # --- APR (§940) ---
    # Actuarial method per Appendix J, Regulation Z (12 CFR Part 1026).
    # Rounded to nearest 10 basis points per §901(a)(5).

    def apr
      @apr ||= begin
        raw_apr = calculate_apr
        round_to_ten_basis_points(raw_apr)
      end
    end

    # --- Prepayment (§910(a)(8-10)) ---

    def prepayment
      @prepayment ||= {
        has_non_interest_charges: @prepayment_penalty_max.positive?,
        max_non_interest_finance_charge: @prepayment_penalty_max.positive? ? @prepayment_penalty_max : nil,
        has_additional_fees: @additional_prepayment_fees.any?,
        additional_fees: @additional_prepayment_fees
      }
    end

    # --- Output Methods ---

    def to_h
      {
        amount_financed: amount_financed.round(2),
        apr: apr,
        finance_charge: finance_charge.round(2),
        total_payment_amount: total_payment_amount.round(2),
        payment_amount: payment_amount.round(2),
        payment_frequency: payment_frequency,
        term_days: term_days,
        term_display: term_display,
        average_monthly_cost: average_monthly_cost&.round(2),
        recipient_funds: recipient_funds.round(2),
        prepayment: prepayment
      }
    end

    def to_labeled_h
      {
        amount_financed: { label: 'Funding Provided', value: amount_financed.round(2) },
        apr: { label: 'Annual Percentage Rate (APR)', value: apr },
        finance_charge: { label: 'Finance Charge', value: finance_charge.round(2) },
        total_payment_amount: { label: 'Total Payment Amount', value: total_payment_amount.round(2) },
        payment_amount: { label: 'Payment', value: payment_amount.round(2) },
        payment_frequency: { label: 'Payment Frequency', value: payment_frequency },
        term_days: { label: 'Term', value: term_display },
        average_monthly_cost: { label: 'Average Monthly Cost', value: average_monthly_cost&.round(2) },
        recipient_funds: { label: 'Recipient Funds', value: recipient_funds.round(2) },
        prepayment: prepayment
      }
    end

    private

    def disbursement_date
      @schedule.start_date
    end

    def principal
      @schedule.principal
    end

    def origination_fee
      @schedule.origination_fee
    end

    def additional_fee
      @schedule.additional_fee
    end

    def fee_treatment
      @schedule.additional_fee_treatment
    end

    # --- APR Calculation ---
    #
    # Solves for the annual rate i such that:
    #   Amount Financed = Σ (Payment_k / (1 + i/365)^(days_k))
    #
    # where days_k is the number of days from disbursement to payment k.
    #
    # Uses Newton-Raphson with bisection fallback.

    def calculate_apr
      cash_flows = extract_cash_flows
      return 0.0 if cash_flows.empty?
      return 0.0 if amount_financed <= 0
      return 0.0 if cash_flows.length > 10_000

      # Initial guess: use the nominal annual rate as starting point
      guess = @schedule.annual_rate
      guess = 0.10 if guess.zero?

      apr_newton_raphson(cash_flows, guess) || apr_bisection(cash_flows)
    end

    def extract_cash_flows
      flows = []
      start = disbursement_date

      @schedule.schedule.each do |row|
        payment = row[:total_payment]
        next if payment.nil? || payment <= 0

        days_from_start = (row[:date] - start).to_i
        next if days_from_start <= 0

        flows << { days: days_from_start, amount: payment }
      end

      flows
    end

    # Present value of all payments at annual rate r, minus amount financed.
    # When this equals zero, r is the APR.
    def pv_function(cash_flows, annual_rate)
      daily_rate = annual_rate / 365.0
      pv = cash_flows.sum do |cf|
        cf[:amount] / ((1.0 + daily_rate)**cf[:days])
      end
      pv - amount_financed
    end

    # Derivative of the PV function with respect to annual_rate.
    def pv_derivative(cash_flows, annual_rate)
      daily_rate = annual_rate / 365.0
      cash_flows.sum do |cf|
        -cf[:days] * cf[:amount] / (365.0 * ((1.0 + daily_rate)**(cf[:days] + 1)))
      end
    end

    def apr_newton_raphson(cash_flows, initial_guess)
      rate = initial_guess

      APR_MAX_ITERATIONS.times do
        f = pv_function(cash_flows, rate)
        f_prime = pv_derivative(cash_flows, rate)

        return rate * 100.0 if f.abs < APR_CONVERGENCE_TOLERANCE
        return nil if f_prime.abs < 1e-15 # derivative too small, switch to bisection

        step = f / f_prime
        rate -= step

        # Guard against negative rates or runaway
        return nil if rate <= -1.0 / 365.0
        return nil if rate > 10.0 # 1000% APR cap — something went wrong
      end

      nil # didn't converge
    end

    def apr_bisection(cash_flows)
      low = -0.001
      high = 10.0

      # Ensure the interval brackets the root
      f_low = pv_function(cash_flows, low)
      f_high = pv_function(cash_flows, high)

      # If both same sign, try expanding
      if (f_low * f_high).positive?
        high = 50.0
        f_high = pv_function(cash_flows, high)
        return 0.0 if (f_low * f_high).positive?
      end

      (APR_MAX_ITERATIONS * 5).times do
        mid = (low + high) / 2.0
        f_mid = pv_function(cash_flows, mid)

        return mid * 100.0 if f_mid.abs < APR_CONVERGENCE_TOLERANCE

        if (f_low * f_mid).negative?
          high = mid
        else
          low = mid
          f_low = f_mid
        end
      end

      ((low + high) / 2.0) * 100.0
    end

    def round_to_ten_basis_points(apr_percent)
      (apr_percent * 10).round / 10.0
    end
  end
end
