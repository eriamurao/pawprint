require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:task)).to be_valid
    end

    it 'requires content' do
      task = build(:task, content: nil)
      expect(task).not_to be_valid
      expect(task.errors[:content]).to include("can't be blank")
    end

    it 'requires log_year' do
      task = build(:task, log_year: nil)
      expect(task).not_to be_valid
      expect(task.errors[:log_year]).to include("can't be blank")
    end

    it 'requires log_month' do
      task = build(:task, log_month: nil)
      expect(task).not_to be_valid
      expect(task.errors[:log_month]).to include("can't be blank")
    end

    it 'does not require log_day' do
      task = build(:task, log_day: nil)
      expect(task).to be_valid
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
        'open', 'in_progress', 'completed', 'cancelled', 'deferred', 'rescheduled'
      )
    end
  end

  describe 'created_from association' do
    it 'is optional' do
      expect(build(:task, created_from: nil)).to be_valid
    end

    it 'links to the task it was created from' do
      original = create(:task)
      successor = create(:task, created_from: original)

      expect(successor.created_from).to eq(original)
    end
  end
end
