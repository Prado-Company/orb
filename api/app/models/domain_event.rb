class DomainEvent < ApplicationRecord
  validates :event_id, :event_type, :occurred_at, :actor_type, :actor_id,
            :resource_type, :resource_id, :source, :correlation_id, :privacy_level,
            presence: true
  validates :source, inclusion: { in: Foundation::EventRecorder::VALID_SOURCES }
  validates :privacy_level, inclusion: { in: Foundation::EventRecorder::VALID_PRIVACY_LEVELS }

  def envelope
    {
      version: 1,
      event_id: event_id,
      event_type: event_type,
      occurred_at: occurred_at.utc.iso8601,
      actor: { type: actor_type, id: actor_id },
      resource: { type: resource_type, id: resource_id },
      source: source,
      correlation_id: correlation_id,
      privacy_level: privacy_level,
      metadata_minima: metadata_minima
    }
  end
end
