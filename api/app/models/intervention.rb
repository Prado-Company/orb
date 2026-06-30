class Intervention < ApplicationRecord
  FEEDBACK_VALUES = %w[ajudou neutro nao_ajudou outro].freeze

  belongs_to :user

  validates :intervention_type, :estimated_minutes, :started_at, :source, presence: true
  validates :feedback, inclusion: { in: FEEDBACK_VALUES }, allow_blank: true
end
