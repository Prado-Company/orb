require "rails_helper"

RSpec.describe "API v1 history sprint 4", type: :request do
  it "returns a short Free timeline and keeps older data stored when the user downgrades" do
    user = create_user(email: "history@example.com", name: "History")
    task = user.tasks.create!(title: "Produzir relatorio", status: "nao_iniciado", origin: "user")
    event = user.events.create!(
      title: "Bloco de foco",
      starts_at: 1.day.ago,
      ends_at: 1.day.ago + 1.hour,
      timezone: "America/Bahia",
      status: "confirmado",
      origin: "user"
    )
    old_event = create_domain_event(
      user: user,
      resource_type: "tarefa",
      resource_id: task.id,
      event_type: "tarefa_atualizada",
      occurred_at: 20.days.ago
    )
    recent_event = create_domain_event(
      user: user,
      resource_type: "evento",
      resource_id: event.id,
      event_type: "evento_criado",
      occurred_at: 1.day.ago
    )
    user.energies.create!(
      value: 62,
      qualitative_state: "media",
      calibration_source: "historico",
      confidence: "media",
      measured_at: 2.days.ago,
      factors: ["historico_recente"],
      source: "web"
    )

    get "/api/v1/history", headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_history_free" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("entitlement", "history_window_days")).to eq(14)
    expect(parsed_body.dig("entitlement", "downgrade_behavior")).to include("downgrade_preserva")
    expect(parsed_body.fetch("history").map { |entry| entry.dig("resource", "id") }).to include(event.id.to_s)
    expect(parsed_body.fetch("history").map { |entry| entry.dig("resource", "id") }).not_to include(task.id.to_s)

    user.update!(plan: "pro")
    get "/api/v1/history", headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_history_pro" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("entitlement", "full_history")).to be(true)
    expect(parsed_body.fetch("history").map { |entry| entry.fetch("event_type") }).to include("tarefa_atualizada", "evento_criado", "energia_registrada")

    user.update!(plan: "free")
    expect { get "/api/v1/history", headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_history_downgrade" } }
      .not_to change(DomainEvent, :count)
    expect(DomainEvent.exists?(old_event.id)).to be(true)
    expect(DomainEvent.exists?(recent_event.id)).to be(true)
  end

  it "uses minimized tombstones for deleted tasks in history" do
    user = create_user(email: "history-delete@example.com", name: "History Delete")
    task = user.tasks.create!(title: "Titulo privado", context: "Contexto sensivel", status: "nao_iniciado", origin: "user")
    task.update!(deleted_at: Time.current)
    create_domain_event(
      user: user,
      resource_type: "tarefa",
      resource_id: task.id,
      event_type: "tarefa_excluida",
      occurred_at: 1.hour.ago,
      metadata_minima: { status: "nao_iniciado" }
    )

    get "/api/v1/history", headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_history_tombstone" }

    expect(response).to have_http_status(:ok)
    task_entry = parsed_body.fetch("history").find { |entry| entry.fetch("event_type") == "tarefa_excluida" }
    expect(task_entry.fetch("summary")).to include("tombstone" => true)
    expect(task_entry.to_s).not_to include("Titulo privado", "Contexto sensivel")
  end

  def create_domain_event(user:, resource_type:, resource_id:, event_type:, occurred_at:, metadata_minima: {})
    DomainEvent.create!(
      event_id: "evt_spec_#{SecureRandom.hex(8)}",
      event_type: event_type,
      occurred_at: occurred_at,
      actor_type: "usuario",
      actor_id: user.id.to_s,
      resource_type: resource_type,
      resource_id: resource_id.to_s,
      source: "web",
      correlation_id: "cor_spec_history",
      privacy_level: resource_type == "energia" ? "sensivel" : "interno",
      metadata_minima: metadata_minima
    )
  end
end
