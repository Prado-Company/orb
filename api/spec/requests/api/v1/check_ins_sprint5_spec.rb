require "rails_helper"

RSpec.describe "API v1 check-ins sprint 5", type: :request do
  it "enforces the Free daily limit on the server when creating check-ins" do
    user = create_user(email: "free-limit@example.com", name: "Free Limit")

    2.times do |index|
      post "/api/v1/check_ins",
           params: { check_in: { tipo: "estado_energia", pergunta_id: "q_free_#{index}", horario_previsto: "08:0#{index}" } },
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_free_limit_#{index}" }

      expect(response).to have_http_status(:created)
      expect(parsed_body.dig("daily_limit", "limit")).to eq(2)
      expect(parsed_body.dig("daily_limit", "enforced_by")).to eq("server")
    end

    post "/api/v1/check_ins",
         params: { check_in: { tipo: "estado_energia", pergunta_id: "q_free_3", horario_previsto: "10:00" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_free_limit_block" }

    expect(response).to have_http_status(:too_many_requests)
    expect(parsed_body.dig("error", "code")).to eq("daily_check_in_limit_reached")
    expect(parsed_body.dig("error", "correlation_id")).to eq("cor_free_limit_block")
    expect(user.check_ins.count).to eq(2)
  end

  it "allows Pro users up to five daily check-ins" do
    user = create_user(email: "pro-limit@example.com", name: "Pro Limit")
    user.update!(plan: "pro")

    5.times do |index|
      post "/api/v1/check_ins",
           params: { check_in: { tipo: "estado_energia", pergunta_id: "q_pro_#{index}", horario_previsto: "09:0#{index}" } },
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_pro_limit_#{index}" }

      expect(response).to have_http_status(:created)
    end

    post "/api/v1/check_ins",
         params: { check_in: { tipo: "estado_energia", pergunta_id: "q_pro_6", horario_previsto: "11:00" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_pro_limit_block" }

    expect(response).to have_http_status(:too_many_requests)
    expect(parsed_body.dig("error", "details").to_s).to include("pro_limit_5")
  end

  it "saves a response, recalibrates energy and emits minimized events" do
    user = create_user(email: "checkin-response@example.com", name: "Check Response")
    check_in = user.check_ins.create!(
      kind: "estado_energia",
      question_id: "q_estado_energia_v1",
      scheduled_time: "08:00",
      timezone: "America/Bahia",
      origin: "manual",
      source: "web"
    )
    user.tasks.create!(title: "Produzir relatorio", category: "trabalho", weight: "medio", status: "nao_iniciado", origin: "user")
    user.events.create!(
      title: "Bloco de foco",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      timezone: "America/Bahia",
      status: "confirmado",
      origin: "user"
    )

    post "/api/v1/check_ins/#{check_in.id}/responses",
         params: { response: { resposta: "bom" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_checkin_response" }

    expect(response).to have_http_status(:created)
    expect(parsed_body).to include("status" => "respondido", "privacy_level" => "sensivel")
    expect(parsed_body.dig("check_in", "resposta")).to eq("bom")
    expect(parsed_body.dig("energy", "estado_qualitativo")).to eq("media")
    expect(parsed_body.dig("energy", "fatores")).to include("resposta_check_in", "tarefas_recentes", "eventos_recentes")
    expect(parsed_body.dig("energy", "reason_codes")).to include("resposta_check_in", "delta_check_in_bom", "motor_deterministico_v1")
    expect(DomainEvent.where(event_type: "check_in_respondido", correlation_id: "cor_checkin_response")).to exist
    expect(DomainEvent.where(event_type: "energia_recalibrada", correlation_id: "cor_checkin_response")).to exist
    expect(DomainEvent.last.metadata_minima.to_s).not_to include("Produzir relatorio", "Bloco de foco")
    expect(DomainEvent.last.metadata_minima.fetch("reason_codes")).to include("motor_deterministico_v1")
  end

  it "softly postpones once and neutralizes the second postponement" do
    user = create_user(email: "postpone@example.com", name: "Postpone")
    check_in = user.check_ins.create!(
      kind: "estado_energia",
      question_id: "q_estado_energia_v1",
      scheduled_time: "08:00",
      timezone: "America/Bahia",
      origin: "manual",
      source: "web"
    )

    post "/api/v1/check_ins/#{check_in.id}/responses",
         params: { response: { resposta: "prefiro_responder_depois" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_postpone_wait" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body).to include("status" => "adiado")
    expect(parsed_body.fetch("energy")).to be_nil
    expect(check_in.reload).to have_attributes(postponements: 1, response: nil)
    expect(DomainEvent.where(event_type: "check_in_adiado", correlation_id: "cor_postpone_wait")).to exist

    post "/api/v1/check_ins/#{check_in.id}/responses",
         params: { response: { resposta: "adiar" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_postpone_neutral" }

    expect(response).to have_http_status(:created)
    expect(parsed_body.dig("check_in", "resposta")).to eq("neutro")
    expect(parsed_body.dig("energy", "estado_qualitativo")).to eq("media")
    expect(check_in.reload.postponements).to eq(2)
  end

  it "uses historical patterns after long inactivity instead of old check-ins" do
    user = create_user(email: "inactive@example.com", name: "Inactive")
    user.check_ins.create!(
      kind: "estado_energia",
      question_id: "q_old",
      response: "alto",
      answered_at: 12.days.ago,
      scheduled_time: "08:00",
      timezone: "America/Bahia",
      origin: "manual",
      source: "web",
      created_at: 12.days.ago,
      updated_at: 12.days.ago
    )
    check_in = user.check_ins.create!(
      kind: "estado_energia",
      question_id: "q_now",
      scheduled_time: "08:00",
      timezone: "America/Bahia",
      origin: "manual",
      source: "web"
    )

    post "/api/v1/check_ins/#{check_in.id}/responses",
         params: { response: { resposta: "baixo" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_long_inactivity" }

    expect(response).to have_http_status(:created)
    expect(parsed_body.dig("energy", "fatores")).to include("padroes_historicos", "longa_inatividade")
    expect(parsed_body.dig("energy", "reason_codes")).to include("padroes_historicos", "longa_inatividade")
    expect(parsed_body.dig("energy", "fatores")).not_to include("check_ins_antigos", "historico_recente")
  end

  it "does not let another user answer a private check-in" do
    owner = create_user(email: "check-owner@example.com", name: "Owner")
    other = create_user(email: "check-other@example.com", name: "Other")
    check_in = owner.check_ins.create!(
      kind: "estado_energia",
      question_id: "q_private",
      scheduled_time: "08:00",
      timezone: "America/Bahia",
      origin: "manual",
      source: "web"
    )

    post "/api/v1/check_ins/#{check_in.id}/responses",
         params: { response: { resposta: "alto" } },
         headers: { "Cookie" => issue_cookie_for(other), "X-Correlation-ID" => "cor_check_cross" }

    expect(response).to have_http_status(:not_found)
    expect(check_in.reload.response).to be_nil
  end

  it "prevents response replay from recalibrating energy twice" do
    user = create_user(email: "check-replay@example.com", name: "Replay")
    check_in = user.check_ins.create!(
      kind: "estado_energia",
      question_id: "q_replay",
      scheduled_time: "08:00",
      timezone: "America/Bahia",
      origin: "manual",
      source: "web"
    )

    post "/api/v1/check_ins/#{check_in.id}/responses",
         params: { response: { resposta: "alto" } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_check_replay_first" }

    expect(response).to have_http_status(:created)

    expect do
      post "/api/v1/check_ins/#{check_in.id}/responses",
           params: { response: { resposta: "baixo" } },
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_check_replay_second" }
    end.not_to change(Energy, :count)

    expect(response).to have_http_status(:conflict)
    expect(parsed_body.dig("error", "code")).to eq("check_in_already_answered")
  end

  it "validates official energy states" do
    user = create_user(email: "energy-state@example.com", name: "Energy State")

    expect do
      user.energies.create!(
        value: 80,
        qualitative_state: "produtivo",
        calibration_source: "check_in",
        confidence: "media",
        measured_at: Time.current,
        factors: ["resposta_check_in"],
        source: "web"
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
