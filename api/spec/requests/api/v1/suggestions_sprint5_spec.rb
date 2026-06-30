require "rails_helper"

RSpec.describe "API v1 suggestions sprint 5", type: :request do
  it "returns one deterministic next action for the authenticated user" do
    user = create_user(email: "next-action@example.com", name: "Next Action")
    task = user.tasks.create!(
      title: "Produzir relatorio",
      category: "trabalho",
      estimated_minutes: 45,
      weight: "medio",
      status: "nao_iniciado",
      origin: "user"
    )
    user.events.create!(
      title: "Reuniao",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      timezone: "America/Bahia",
      status: "confirmado",
      origin: "user"
    )
    user.energies.create!(
      value: 62,
      qualitative_state: "media",
      calibration_source: "check_in",
      confidence: "media",
      measured_at: Time.current,
      factors: ["resposta_check_in"],
      source: "web"
    )

    post "/api/v1/suggestions/next_action",
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_next_action" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body).to include(
      "decision_engine" => "deterministico",
      "llm_used" => false,
      "fallback_available" => true,
      "privacy_level" => "sensivel"
    )
    expect(parsed_body.dig("action", "type")).to eq("comecar")
    expect(parsed_body.dig("action", "resource")).to eq({ "type" => "tarefa", "id" => task.id.to_s })
    expect(parsed_body.fetch("actions_available")).to contain_exactly("comecar", "adiar", "trocar")
    expect(parsed_body.fetch("reason_codes")).to include("motor_deterministico_v1", "fits_available_window")
    expect(parsed_body.fetch("score")).to be_a(Integer)
    expect(parsed_body.fetch("drenagem_prevista")).to be_a(Integer)
    expect(parsed_body.dig("explanation_inputs", "score_components")).to include("prazo", "compatibilidade_energia", "penalidade_drenagem")
    expect(parsed_body.fetch("reason").downcase).not_to include("llm", "ia ")
    expect(response.body).not_to include("Produzir relatorio")
    expect(Suggestion.find(parsed_body.fetch("suggestion_id")).user_id).to eq(user.id)
  end

  it "blocks task scoring when an event starts in the next ten minutes" do
    user = create_user(email: "next-event-soon@example.com", name: "Next Event Soon")
    user.tasks.create!(title: "Separar notas", category: "trabalho", estimated_minutes: 10, weight: "leve", status: "nao_iniciado", origin: "user")
    event = user.events.create!(
      title: "Reuniao curta",
      starts_at: 5.minutes.from_now,
      ends_at: 35.minutes.from_now,
      timezone: "America/Bahia",
      status: "confirmado",
      origin: "user"
    )
    user.energies.create!(
      value: 58,
      qualitative_state: "media",
      calibration_source: "check_in",
      confidence: "media",
      measured_at: Time.current,
      factors: ["resposta_check_in"],
      source: "web"
    )

    post "/api/v1/suggestions/next_action",
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_event_soon" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("action", "type")).to eq("preparar_evento")
    expect(parsed_body.dig("action", "resource")).to eq({ "type" => "evento", "id" => event.id.to_s })
    expect(parsed_body.fetch("reason_codes")).to include("evento_comeca_em_ate_10_min", "bloqueio_pre_score")
    expect(parsed_body.fetch("score")).to be_nil
  end

  it "protects overload by suggesting regulation instead of a task" do
    user = create_user(email: "overload@example.com", name: "Overload")
    user.tasks.create!(
      title: "Tarefa pesada",
      category: "trabalho",
      estimated_minutes: 20,
      weight: "leve",
      status: "nao_iniciado",
      origin: "user"
    )
    user.energies.create!(
      value: 20,
      qualitative_state: "em_sobrecarga",
      calibration_source: "check_in",
      confidence: "media",
      measured_at: Time.current,
      factors: ["resposta_check_in"],
      source: "web"
    )

    post "/api/v1/suggestions/next_action",
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_overload_regulation" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("action", "type")).to eq("regular")
    expect(parsed_body.dig("action", "resource", "type")).to eq("intervencao")
    expect(parsed_body.dig("explanation_inputs", "energia_estado")).to eq("em_sobrecarga")
    expect(parsed_body.fetch("reason_codes")).to include("estado_em_sobrecarga", "regulacao_antes_de_tarefa")
    expect(parsed_body.fetch("score")).to be_nil
    expect(parsed_body.fetch("drenagem_prevista")).to be_nil
    expect(parsed_body.fetch("reason")).to include("regulacao")
    expect(parsed_body.fetch("reason").downcase).not_to include("llm", "ia ")
  end

  it "protects recovery mode after a recent intervention" do
    user = create_user(email: "recovery@example.com", name: "Recovery")
    user.tasks.create!(title: "Revisar proposta", category: "trabalho", estimated_minutes: 20, weight: "leve", status: "nao_iniciado", origin: "user")
    user.energies.create!(
      value: 58,
      qualitative_state: "media",
      calibration_source: "check_in",
      confidence: "media",
      measured_at: Time.current,
      factors: ["resposta_check_in"],
      source: "web"
    )
    user.interventions.create!(
      intervention_type: "pausa_curta",
      trigger: "recuperacao",
      estimated_minutes: 5,
      started_at: 10.minutes.ago,
      ended_at: 5.minutes.ago,
      source: "web"
    )

    post "/api/v1/suggestions/next_action",
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_recovery_protected" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("action", "type")).to eq("regular")
    expect(parsed_body.fetch("reason_codes")).to include("estado_em_recuperacao", "regulacao_antes_de_tarefa")
  end

  it "requires authentication" do
    post "/api/v1/suggestions/next_action", headers: { "X-Correlation-ID" => "cor_next_auth" }

    expect(response).to have_http_status(:unauthorized)
    expect(parsed_body.dig("error", "code")).to eq("authentication_required")
  end

  it "records accepted, postponed and exchanged suggestion actions server-side" do
    user = create_user(email: "suggestion-actions@example.com", name: "Suggestion Actions")
    suggestion = user.suggestions.create!(
      suggested_item_type: "tarefa",
      suggested_item_id: 123,
      reason: "Cabe na janela atual.",
      available_actions: %w[comecar adiar trocar],
      summarized_input: { energia_estado: "media", llm_used: false },
      source: "web",
      privacy_level: "sensivel"
    )

    post "/api/v1/suggestions/#{suggestion.id}/actions",
         params: { suggestion_action: { action: "comecar" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_suggestion_accept" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("action_taken")).to eq("comecar")
    expect(parsed_body.dig("event", "event_type")).to eq("sugestao_aceita")

    post "/api/v1/suggestions/#{suggestion.id}/actions",
         params: { suggestion_action: { action: "adiar" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_suggestion_postpone" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("event", "event_type")).to eq("sugestao_adiada")
    expect(parsed_body.dig("event", "metadata_minima", "punitive")).to be(false)

    post "/api/v1/suggestions/#{suggestion.id}/actions",
         params: { suggestion_action: { action: "trocar" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_suggestion_exchange" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("event", "event_type")).to eq("sugestao_trocada")
    expect(DomainEvent.where(event_type: "sugestao_trocada", correlation_id: "cor_suggestion_exchange")).to exist
  end
end
