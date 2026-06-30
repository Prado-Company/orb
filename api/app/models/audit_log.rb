class AuditLog < ApplicationRecord
  validates :actor_type, :action, :privacy_level, :correlation_id, presence: true
  validates :privacy_level, inclusion: { in: Foundation::EventRecorder::VALID_PRIVACY_LEVELS }
end
