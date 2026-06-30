require "rails_helper"

RSpec.describe "API v1 events sprint 4", type: :request do
  it "creates an anchored event and calculates the available window until the next event" do
    user = create_user(email: "event-owner@example.com", name: "Event Owner")

    post "/api/v1/events",
         params: {
           event: {
             titulo: "Bloco de foco",
             inicio: "2026-06-14T13:00:00Z",
             fim: "2026-06-14T14:00:00Z",
             timezone: "America/Bahia",
             categoria: "trabalho",
             peso: "leve"
           }
         },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_event_create" }

    expect(response).to have_http_status(:created)
    expect(parsed_body.dig("event", "origem")).to eq("usuario")
    expect(parsed_body.dig("event", "inicio")).to eq("2026-06-14T13:00:00Z")
    expect(DomainEvent.where(event_type: "evento_criado", correlation_id: "cor_event_create")).to exist

    get "/api/v1/events",
        params: { at: "2026-06-14T12:20:00Z" },
        headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_event_window" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("available_window_minutes")).to eq(40)
  end

  it "rejects invalid event anchors" do
    user = create_user(email: "event-invalid@example.com", name: "Event Invalid")

    post "/api/v1/events",
         params: {
           event: {
             titulo: "Horario invalido",
             inicio: "2026-06-14T14:00:00Z",
             fim: "2026-06-14T13:00:00Z",
             timezone: "America/Bahia",
             categoria: "trabalho",
             peso: "leve"
           }
         },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_event_invalid" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(parsed_body.dig("error", "code")).to eq("validation_failed")
    expect(response.body).not_to include("Horario invalido")
  end

  it "blocks update and delete for external-origin events without explicit consent" do
    user = create_user(email: "external-event@example.com", name: "External Event")
    event = user.events.create!(
      title: "Evento importado",
      starts_at: "2026-06-14T13:00:00Z",
      ends_at: "2026-06-14T14:00:00Z",
      timezone: "America/Bahia",
      category: "trabalho",
      weight: "leve",
      status: "confirmado",
      origin: "integration",
      external_ref: "google-calendar:evt_123"
    )

    patch "/api/v1/events/#{event.id}",
          params: { changes: { titulo: "Alteracao externa" } },
          headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_event_external_update" }

    expect(response).to have_http_status(:forbidden)
    expect(parsed_body.dig("error", "code")).to eq("external_calendar_write_requires_consent")
    expect(event.reload.title).to eq("Evento importado")

    delete "/api/v1/events/#{event.id}",
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_event_external_delete" }

    expect(response).to have_http_status(:forbidden)
    expect(parsed_body.dig("error", "code")).to eq("external_calendar_write_requires_consent")
    expect(event.reload.deleted_at).to be_nil
  end

  it "does not let another user see or mutate an event" do
    owner = create_user(email: "event-owner-2@example.com", name: "Owner")
    other = create_user(email: "event-other@example.com", name: "Other")
    event = owner.events.create!(
      title: "Privado",
      starts_at: "2026-06-14T13:00:00Z",
      ends_at: "2026-06-14T14:00:00Z",
      timezone: "America/Bahia",
      status: "confirmado",
      origin: "user"
    )

    get "/api/v1/events/#{event.id}",
        headers: { "Cookie" => issue_cookie_for(other), "X-Correlation-ID" => "cor_event_cross_show" }

    expect(response).to have_http_status(:not_found)

    patch "/api/v1/events/#{event.id}",
          params: { changes: { titulo: "Tentativa" } },
          headers: { "Cookie" => issue_cookie_for(other), "X-Correlation-ID" => "cor_event_cross_update" }

    expect(response).to have_http_status(:not_found)
    expect(event.reload.title).to eq("Privado")
  end
end
