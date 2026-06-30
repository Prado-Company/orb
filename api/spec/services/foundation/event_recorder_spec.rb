require "rails_helper"

RSpec.describe Foundation::EventRecorder do
  it "persists a minimized domain event envelope" do
    event = described_class.record_event(
      event_type: "check_in_respondido",
      actor: { type: "usuario", id: "1" },
      resource: { type: "check_in", id: "2" },
      source: "web",
      correlation_id: "cor_event_12345",
      privacy_level: "sensivel",
      metadata_minima: { token: "secret", resposta_tipo: "escala" }
    )

    expect(event).to include(
      event_type: "check_in_respondido",
      source: "web",
      correlation_id: "cor_event_12345",
      privacy_level: "sensivel"
    )
    expect(event.dig(:metadata_minima, :token)).to eq("[REDACTED]")
    expect(DomainEvent.find_by!(event_id: event[:event_id]).metadata_minima).to include("token" => "[REDACTED]")
  end

  it "rejects unknown source values" do
    expect do
      described_class.build_event(
        event_type: "tarefa_criada",
        actor: { type: "usuario", id: "1" },
        resource: { type: "tarefa", id: "2" },
        source: "desktop",
        correlation_id: "cor_event_12345",
        privacy_level: "interno"
      )
    end.to raise_error(ArgumentError, "invalid_source")
  end
end
