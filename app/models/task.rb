class Task < ApplicationRecord
  belongs_to :created_from, class_name: "Task", optional: true

  validates :content, presence: true
  validates :status, presence: true
  validates :log_year, :log_month, presence: true

  enum :status, { open: 0, in_progress: 1, completed: 2, cancelled: 3, deferred: 4, rescheduled: 5 }
end
