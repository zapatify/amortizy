# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe Amortizy::CsvFormatter do
  let(:schedule) do
    Amortizy::AmortizationSchedule.new(
      start_date: '2026-01-15',
      principal: 10_000.00,
      term_months: 3,
      frequency: :monthly,
      annual_rate: 10.0
    )
  end

  let(:csv_path) { 'tmp_test_formatter.csv' }

  after { FileUtils.rm_f(csv_path) }

  describe '#render' do
    it 'writes CSV with correct headers' do
      described_class.new(schedule).render(csv_path)
      content = File.read(csv_path)
      expect(content).to include('Payment Number')
      expect(content).to include('Principal Balance Remaining')
      expect(content).to include('Grace Interest Capitalized')
    end

    it 'writes one row per schedule entry plus header' do
      described_class.new(schedule).render(csv_path)
      lines = File.readlines(csv_path)
      expect(lines.length).to eq(schedule.schedule.length + 1)
    end
  end
end
