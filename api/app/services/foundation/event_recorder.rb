module Foundation
  class EventRecorder
    VALID_SOURCES = %w[web android ios admin job integration].freeze
    VALID_PRIVACY_LEVELS = %w[publico interno sensivel agregado financeiro].freeze

    def self.record_event(event_type:, actor:, resource:, source:, correlation_id:, privacy_level:, metadata_minima: {})
      envelope = build_event(
        event_type: event_type,
        actor: actor,
        resource: resource,
        source: source,
        correlation_id: correlation_id,
        privacy_level: privacy_level,
        metadata_minima: metadata_minima
      )

      DomainEvent.create!(
        event_id: envelope[:event_id],
        event_type: envelope[:event_type],
        occurred_at: Time.iso8601(envelope[:occurred_at]),
        actor_type: envelope.dig(:actor, :type),
        actor_id: envelope.dig(:actor, :id),
        resource_type: envelope.dig(:resource, :type),
        resource_id: envelope.dig(:resource, :id),
        source: envelope[:source],
        correlation_id: envelope[:correlation_id],
        privacy_level: envelope[:privacy_level],
        metadata_minima: envelope[:metadata_minima]
      )

      envelope
    end

    def self.build_event(event_type:, actor:, resource:, source:, correlation_id:, privacy_level:, metadata_minima: {})
      raise ArgumentError, "invalid_source" unless VALID_SOURCES.include?(source)
      raise ArgumentError, "invalid_privacy_level" unless VALID_PRIVACY_LEVELS.include?(privacy_level)

      {
        version: 1,
        event_id: "evt_#{SecureRandom.uuid}",
        event_type: event_type,
        occurred_at: Time.now.utc.iso8601,
        actor: actor,
        resource: resource,
        source: source,
        correlation_id: correlation_id,
        privacy_level: privacy_level,
        metadata_minima: LogSanitizer.redact(metadata_minima)
      }
    end
  end
end
