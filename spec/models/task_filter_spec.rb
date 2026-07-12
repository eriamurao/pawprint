require 'rails_helper'

RSpec.describe TaskFilter, type: :model do
  describe 'validations' do
    it 'is valid with type daily and a date' do
      filter = described_class.new(type: 'daily', date: '2026-07-10')
      expect(filter).to be_valid
    end

    it 'is valid with type monthly and a date' do
      filter = described_class.new(type: 'monthly', date: '2026-07-10')
      expect(filter).to be_valid
    end

    it 'requires type to be daily or monthly' do
      filter = described_class.new(type: 'yearly', date: '2026-07-10')
      expect(filter).not_to be_valid
      expect(filter.errors[:type]).to include('is not included in the list')
    end

    it 'is invalid without a type' do
      filter = described_class.new(type: nil, date: '2026-07-10')
      expect(filter).not_to be_valid
      expect(filter.errors[:type]).to include('is not included in the list')
    end

    it 'is invalid without a date' do
      filter = described_class.new(type: 'daily', date: nil)
      expect(filter).not_to be_valid
      expect(filter.errors[:date]).to include('is invalid')
    end

    it 'is invalid with an unparseable date' do
      filter = described_class.new(type: 'daily', date: 'not-a-date')
      expect(filter).not_to be_valid
      expect(filter.errors[:date]).to include('is invalid')
    end
  end

  describe '#to_query' do
    it 'returns the attributes as a symbolized hash' do
      filter = described_class.new(type: 'daily', date: '2026-07-10')

      expect(filter.to_query).to eq(type: 'daily', date: Date.new(2026, 7, 10))
    end
  end
end
