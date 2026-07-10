require 'rails_helper'

RSpec.describe TaskStateMachine do
  describe 'state machine' do
    it 'defaults to open' do
      expect(build(:task).status).to eq('open')
    end

    it 'starts an open task' do
      task = build(:task, status: 'open')
      task.start!
      expect(task.status).to eq('in_progress')
    end

    it 'stops an in-progress task' do
      task = build(:task, status: 'in_progress')
      task.stop!
      expect(task.status).to eq('open')
    end

    it 'completes an open task' do
      task = build(:task, status: 'open')
      task.complete!
      expect(task.status).to eq('completed')
    end

    it 'completes an in-progress task' do
      task = build(:task, status: 'in_progress')
      task.complete!
      expect(task.status).to eq('completed')
    end

    it 'cancels an open task' do
      task = build(:task, status: 'open')
      task.cancel!
      expect(task.status).to eq('cancelled')
    end

    it 'defers an open task' do
      task = build(:task, status: 'open')
      task.defer!
      expect(task.status).to eq('deferred')
    end

    it 'migrates an open task' do
      task = build(:task, status: 'open')
      task.migrate!
      expect(task.status).to eq('migrated')
    end

    it 'archives an open task' do
      task = build(:task, status: 'open')
      task.archive!
      expect(task.status).to eq('archived')
    end

    it 'reopens a completed task' do
      task = build(:task, status: 'completed')
      task.reopen!
      expect(task.status).to eq('open')
    end

    it 'reopens a cancelled task' do
      task = build(:task, status: 'cancelled')
      task.reopen!
      expect(task.status).to eq('open')
    end

    it 'reopens an archived task' do
      task = build(:task, status: 'archived')
      task.reopen!
      expect(task.status).to eq('open')
    end

    it 'raises when an event cannot transition from the current state' do
      task = build(:task, status: 'completed')
      expect { task.start! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe '#available_events' do
    it 'returns the permissible events with their display labels' do
      task = build(:task, status: 'open')

      expect(task.available_events).to contain_exactly(
        { event: :start, label: 'Start Task' },
        { event: :complete, label: 'Complete Task' },
        { event: :cancel, label: 'Cancel Task' },
        { event: :defer, label: 'Defer Task' },
        { event: :migrate, label: 'Migrate Task' },
        { event: :archive, label: 'Archive Task' }
      )
    end

    it 'returns only reopen from a completed state' do
      task = build(:task, status: 'completed')

      expect(task.available_events).to contain_exactly({ event: :reopen, label: 'Re-open Task' })
    end
  end

  describe '#available_event_names' do
    it 'returns just the event names' do
      task = build(:task, status: 'open')

      expect(task.available_event_names).to contain_exactly(
        :start, :complete, :cancel, :defer, :migrate, :archive
      )
    end
  end

  describe '#event_applyable?' do
    it 'is true for a permissible event' do
      task = build(:task, status: 'open')
      expect(task.event_applyable?(:start)).to eq(true)
    end

    it 'is false for a non-permissible event' do
      task = build(:task, status: 'open')
      expect(task.event_applyable?(:reopen)).to eq(false)
    end

    it 'is false for an unknown event' do
      task = build(:task, status: 'open')
      expect(task.event_applyable?(:bogus)).to eq(false)
    end
  end

  describe '#apply_event' do
    it 'applies a permissible event and returns truthy' do
      task = build(:task, status: 'open')

      expect(task.apply_event(:start)).to be_truthy
      expect(task.status).to eq('in_progress')
    end

    it 'does not apply a non-permissible event and returns false' do
      task = build(:task, status: 'open')

      expect(task.apply_event(:reopen)).to eq(false)
      expect(task.status).to eq('open')
    end

    it 'does not apply an unknown event and returns false' do
      task = build(:task, status: 'open')

      expect(task.apply_event(:bogus)).to eq(false)
      expect(task.status).to eq('open')
    end
  end

  describe '.event_display_name' do
    it 'returns the configured label for a known event' do
      expect(Task.event_display_name(:reopen)).to eq('Re-open Task')
    end

    it 'falls back to a titleized name for an unknown event' do
      expect(Task.event_display_name(:frobnicate)).to eq('Frobnicate')
    end
  end
end
