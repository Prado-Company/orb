class AiUsageLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :usage_type, :status, :source, :correlation_id, presence: true
end
