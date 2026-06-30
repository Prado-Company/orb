class Event < ApplicationRecord
  belongs_to :user
  belongs_to :organization, optional: true

  STATUSES = %w[confirmado cancelado concluido].freeze
  WEIGHTS = %w[leve medio pesado].freeze
  ORIGINS = %w[user integration].freeze

  validates :title, :starts_at, :ends_at, :timezone, :status, :origin, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :weight, inclusion: { in: WEIGHTS }, allow_blank: true
  validates :origin, inclusion: { in: ORIGINS }
  validate :ends_after_start

  scope :active, -> { where(deleted_at: nil) }

  def privacy_level
    return "sensivel" if origin == "integration" || external_ref.present?
    return "sensivel" if category.in?(%w[saude autocuidado terapia])

    "interno"
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, "must be after starts_at")
  end
end
