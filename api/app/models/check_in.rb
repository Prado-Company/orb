class CheckIn < ApplicationRecord
  RESPONSE_VALUES = %w[muito_baixo baixo neutro bom alto].freeze
  POSTPONE_RESPONSES = %w[adiar prefiro_responder_depois].freeze

  belongs_to :user

  validates :kind, :question_id, :scheduled_time, :timezone, :origin, :source, presence: true
  validates :response, inclusion: { in: RESPONSE_VALUES }, allow_nil: true

  def answered?
    answered_at.present?
  end
end
