# frozen_string_literal: true

module TaskStateMachine
  extend ActiveSupport::Concern

  EVENT_DISPLAY_NAMES = {
    start: 'Start Task',
    stop: 'Stop Task',
    complete: 'Complete Task',
    cancel: 'Cancel Task',
    defer: 'Defer Task',
    migrate: 'Migrate Task',
    archive: 'Archive Task',
    reopen: 'Re-open Task'
}.freeze

  included do
    include AASM

    aasm column: :status, enum: true do
      state :open, initial: true
      state :in_progress
      state :completed
      state :cancelled
      state :deferred
      state :migrated
      state :archived

      event :start do
        transitions from: :open, to: :in_progress
      end

      event :stop do
        transitions from: :in_progress, to: :open
      end

      event :complete do
        transitions from: [ :open, :in_progress ], to: :completed
      end

      event :cancel do
        transitions from: [ :open, :in_progress ], to: :cancelled
      end

      event :defer do
        transitions from: [ :open, :in_progress ], to: :deferred
      end

      event :migrate do
        transitions from: [ :open, :in_progress ], to: :migrated
      end

      event :archive do
        transitions from: [ :open, :in_progress ], to: :archived
      end

      event :reopen do
        transitions from: [ :completed, :cancelled, :archived ], to: :open
      end
    end

    def available_events
      aasm.events(permissible: true).map do |event|
        {
          event: event.name,
          label: self.class.event_display_name(event.name)
        }
      end
    end

    def available_event_names
      aasm.events(permissible: true).map(&:name)
    end

    def event_applyable?(event_name)
      available_event_names.include?(event_name&.to_sym) && public_send("may_#{event_name}?")
    end

    def apply_event(event_name)
      event_applyable?(event_name) && public_send("#{event_name}!")
    end
  end

  class_methods do
    def event_display_name(name)
      EVENT_DISPLAY_NAMES[name&.to_sym] || name.to_s.titleize
    end
  end
end
