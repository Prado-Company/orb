module Events
  class ExternalWritePolicy
    ERROR_CODE = "external_calendar_write_requires_consent".freeze

    def initialize(event:, consent:)
      @event = event
      @consent = consent
    end

    def allowed?
      !external_event? || @consent
    end

    private

    def external_event?
      @event.origin == "integration" || @event.external_ref.present?
    end
  end
end
