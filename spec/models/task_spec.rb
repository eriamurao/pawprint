require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:task)).to be_valid
    end

    it 'requires title' do
      task = build(:task, title: nil)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include("can't be blank")
    end

    it 'limits title to 255 characters' do
      task = build(:task, title: 'a' * 256)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include('is too long (maximum is 255 characters)')
    end

    it 'requires log_year' do
      task = build(:task, log_year: nil)
      expect(task).not_to be_valid
      expect(task.errors[:log_year]).to include("can't be blank")
    end

    it 'rejects a log_year before 2000' do
      task = build(:task, log_year: 1999)
      expect(task).not_to be_valid
      expect(task.errors[:log_year]).to include('must be greater than or equal to 2000')
    end

    it 'requires log_month' do
      task = build(:task, log_month: nil)
      expect(task).not_to be_valid
      expect(task.errors[:log_month]).to include("can't be blank")
    end

    it 'rejects a log_month outside 1..12' do
      task = build(:task, log_month: 13)
      expect(task).not_to be_valid
      expect(task.errors[:log_month]).to include('must be in 1..12')
    end

    it 'does not require log_day' do
      task = build(:task, log_day: nil)
      expect(task).to be_valid
    end

    it 'rejects a log_day outside 1..31' do
      task = build(:task, log_day: 32)
      expect(task).not_to be_valid
      expect(task.errors[:log_day]).to include('must be in 1..31')
    end

    it 'requires status' do
      task = build(:task, status: nil)
      expect(task).not_to be_valid
      expect(task.errors[:status]).to include("can't be blank")
    end

    it 'allows priority to be false' do
      task = build(:task, priority: false)
      expect(task).to be_valid
    end

    describe '#log_date_must_be_valid' do
      it 'is valid for a real calendar date' do
        task = build(:task, log_year: 2026, log_month: 7, log_day: 15)
        expect(task).to be_valid
      end

      it 'is invalid for a nonexistent calendar date' do
        task = build(:task, log_year: 2026, log_month: 2, log_day: 30)
        expect(task).not_to be_valid
        expect(task.errors[:date]).to include('should be a valid calendar date')
      end

      it 'defaults log_day to the 1st of the month when nil' do
        task = build(:task, log_year: 2026, log_month: 7, log_day: nil)
        expect(task).to be_valid
      end

      it 'skips the check when log_year is blank' do
        task = build(:task, log_year: nil, log_day: 30)
        task.valid?
        expect(task.errors[:date]).not_to include('should be a valid calendar date')
      end

      it 'skips the check when log_month is blank' do
        task = build(:task, log_month: nil, log_day: 30)
        task.valid?
        expect(task.errors[:date]).not_to include('should be a valid calendar date')
      end
    end
  end

  describe 'defaults' do
    it 'defaults status to open' do
      expect(build(:task).status).to eq('open')
    end

    it 'defaults priority to false' do
      expect(build(:task).priority).to eq(false)
    end
  end

  describe 'status enum' do
    it 'defines the expected statuses' do
      expect(Task.statuses.keys).to contain_exactly(
        'open', 'in_progress', 'completed', 'cancelled', 'deferred', 'migrated', 'archived'
      )
    end
  end

  describe 'created_from association' do
    let(:original_task) { create(:task) }
    let(:successor_task) { create(:task, created_from: original_task) }

    it 'is optional' do
      expect(build(:task, created_from: nil)).to be_valid
    end

    it 'links to the task it was created from' do
      expect(successor_task.created_from).to eq(original_task)
    end
  end

  describe 'callbacks' do
    describe '#split_date (before_validation)' do
      it 'splits a Date given via the virtual date attribute' do
        task = build(:task, date: Date.new(2026, 9, 3), log_year: nil, log_month: nil, log_day: nil)
        expect(task).to be_valid

        expect(task.log_year).to eq(2026)
        expect(task.log_month).to eq(9)
        expect(task.log_day).to eq(3)
      end

      it 'splits a date given as a parseable string' do
        task = build(:task, date: '2026-09-03', log_year: nil, log_month: nil, log_day: nil)
        expect(task).to be_valid

        expect(task.log_year).to eq(2026)
        expect(task.log_month).to eq(9)
        expect(task.log_day).to eq(3)
      end

      it 'leaves log_year/log_month/log_day untouched when date is blank' do
        task = build(:task, date: nil, log_year: 2026, log_month: 7, log_day: 15)
        expect(task).to be_valid

        expect(task.log_year).to eq(2026)
        expect(task.log_month).to eq(7)
        expect(task.log_day).to eq(15)
      end

      it 'adds an error when date is an unparseable string' do
        task = build(:task, date: 'not-a-date')
        expect(task).not_to be_valid
        expect(task.errors[:date]).to include('is invalid')
      end
    end

    describe '#ensure_deletable (before_destroy)' do
      it 'allows destroying a deletable task' do
        task = create(:task, status: :open)

        expect(task.destroy).to be_truthy
        expect(Task.exists?(task.id)).to eq(false)
      end

      it 'blocks destroying a deferred task' do
        task = create(:task, status: :deferred)

        expect(task.destroy).to eq(false)
        expect(task.errors[:base]).to include("can't delete a task that has been deferred or migrated")
        expect(Task.exists?(task.id)).to eq(true)
      end

      it 'blocks destroying a migrated task' do
        task = create(:task, status: :migrated)

        expect(task.destroy).to eq(false)
        expect(Task.exists?(task.id)).to eq(true)
      end
    end
  end

  describe '#log_date' do
    it 'returns nil when log_year is blank' do
      expect(build(:task, log_year: nil).log_date).to be_nil
    end

    it 'returns nil when log_month is blank' do
      expect(build(:task, log_month: nil).log_date).to be_nil
    end

    it 'builds the date from log_year/log_month/log_day' do
      task = build(:task, log_year: 2026, log_month: 7, log_day: 15)
      expect(task.log_date).to eq(Date.new(2026, 7, 15))
    end

    it 'defaults to the 1st of the month when log_day is nil' do
      task = build(:task, log_year: 2026, log_month: 7, log_day: nil)
      expect(task.log_date).to eq(Date.new(2026, 7, 1))
    end

    it 'returns nil for a nonexistent calendar date' do
      task = build(:task, log_year: 2026, log_month: 2, log_day: 30)
      expect(task.log_date).to be_nil
    end
  end

  describe '#deletable?' do
    it 'is true for an open task' do
      expect(build(:task, status: :open).deletable?).to eq(true)
    end

    it 'is false for a deferred task' do
      expect(build(:task, status: :deferred).deletable?).to eq(false)
    end

    it 'is false for a migrated task' do
      expect(build(:task, status: :migrated).deletable?).to eq(false)
    end

    it 'is true for every other status' do
      %i[in_progress completed cancelled archived].each do |status|
        expect(build(:task, status: status).deletable?).to eq(true)
      end
    end
  end

  describe '.scoped_by' do
    let!(:day_task) { create(:task, log_year: 2026, log_month: 7, log_day: 15) }
    let!(:same_month_task) { create(:task, log_year: 2026, log_month: 7, log_day: 20) }
    let!(:other_month_task) { create(:task, log_year: 2026, log_month: 8, log_day: 15) }
    let!(:archived_task) { create(:task, log_year: 2026, log_month: 7, log_day: 15, status: :archived) }

    it 'returns none when type is blank' do
      expect(Task.scoped_by(type: nil, date: Date.new(2026, 7, 15))).to eq([])
    end

    it 'returns none when date is blank' do
      expect(Task.scoped_by(type: 'daily', date: nil)).to eq([])
    end

    it 'raises when date is not a Date or Time' do
      expect { Task.scoped_by(type: 'daily', date: '2026-07-15') }
        .to raise_error(ArgumentError, /date must be a Date or Time/)
    end

    it 'returns none for an unrecognized type' do
      expect(Task.scoped_by(type: 'yearly', date: Date.new(2026, 7, 15))).to eq([])
    end

    it 'scopes to the given day for type daily' do
      result = Task.scoped_by(type: 'daily', date: Date.new(2026, 7, 15))
      expect(result.to_a).to eq([ day_task ])
    end

    it 'scopes to the given month for type monthly' do
      result = Task.scoped_by(type: 'monthly', date: Date.new(2026, 7, 1))
      expect(result).to contain_exactly(day_task, same_month_task)
    end

    it 'excludes other months' do
      result = Task.scoped_by(type: 'monthly', date: Date.new(2026, 7, 1))
      expect(result).not_to include(other_month_task)
    end

    it 'excludes archived tasks when status is blank' do
      result = Task.scoped_by(type: 'monthly', date: Date.new(2026, 7, 1))
      expect(result).not_to include(archived_task)
    end

    it 'includes archived tasks when a status is given' do
      result = Task.scoped_by(type: 'monthly', date: Date.new(2026, 7, 1), status: 'archived')
      expect(result).to include(archived_task)
    end

    it 'orders by created_at ascending' do
      result = Task.scoped_by(type: 'monthly', date: Date.new(2026, 7, 1))
      expect(result.to_a).to eq([ day_task, same_month_task ])
    end
  end
end
