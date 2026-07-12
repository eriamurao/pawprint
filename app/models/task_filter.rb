class TaskFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :type, :string
  attribute :date, :date

  validates :type, inclusion: { in: %w[daily monthly] }
  validate :date_must_be_valid

  def to_query
    attributes.symbolize_keys
  end

  private

  def date_must_be_valid
    errors.add(:date, 'is invalid') if date.blank?
  end
end
