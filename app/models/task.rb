# frozen_string_literal: true

class Task < ApplicationRecord
  NON_DELETABLE_STATUSES = [ :deferred, :migrated ].freeze

  include TaskStateMachine

  attr_accessor :date

  belongs_to :created_from, class_name: 'Task', optional: true

  enum :status, {
    open: 0, in_progress: 1, completed: 2, cancelled: 3, deferred: 4, migrated: 5, archived: 6
  }

  validates :title, presence: true, length: { maximum: 255 }
  validates :status, presence: true
  validates :log_year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 2000 }
  validates :log_month, presence: true, numericality: { only_integer: true, in: 1..12 }
  validates :log_day, allow_nil: true, numericality: { only_integer: true, in: 1..31 }
  validate :log_date_must_be_valid

  before_validation :split_date
  before_destroy :ensure_deletable

  scope :for_month, ->(year, month) { where(log_year: year, log_month: month) }
  scope :for_day, ->(year, month, day) { for_month(year, month).where(log_day: day) }

  scope :unarchived, -> { where.not(status: :archived) }

  def self.scoped_by(type:, date:, status: nil)
    return none if type.blank?
    return none if date.blank?

    unless date.is_a?(Date) || date.is_a?(Time)
      raise ArgumentError, "date must be a Date or Time, got #{date.class}"
    end

    scope =
      case type
      when 'daily'
        for_day(date.year, date.month, date.day)
      when 'monthly'
        for_month(date.year, date.month)
      else
        none
      end

    scope = scope.unarchived if status.blank?
    scope.order(created_at: :asc)
  end

  def log_date
    return if log_year.blank? || log_month.blank?
    # Deferred tasks without log_day attr defaults to 1st of month
    Date.new(log_year, log_month, log_day || 1)
  rescue ArgumentError, TypeError
    nil
  end

  def deletable?
    !NON_DELETABLE_STATUSES.include?(status&.to_sym)
  end

  private

  def log_date_must_be_valid
    return if log_year.blank? || log_month.blank?
    # Deferred tasks without log_day attr defaults to 1st of month for validation
    Date.new(log_year, log_month, log_day || 1)
  rescue ArgumentError, TypeError
    errors.add(:date, 'should be a valid calendar date')
  end

  def split_date
    return if date.blank?

    parsed_date = date.is_a?(String) ? Date.parse(date) : date
    self.log_year = parsed_date.year
    self.log_month = parsed_date.month
    self.log_day = parsed_date.day
  rescue ArgumentError, TypeError
    errors.add(:date, 'is invalid')
  end

  def ensure_deletable
    return if deletable?

    errors.add(:base, "can't delete a task that has been deferred or migrated")
    throw :abort
  end
end
