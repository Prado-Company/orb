require "rails_helper"

RSpec.describe "API v1 interventions sprint 5", type: :request do
  it "starts and finishes an intervention with events and energy recalibration" do
    user = create_user(email: "intervention@example.com", name: "Intervention")
    user.energies.create!(
      value: 24,
      qualitative_state: "em_sobrecarga",
      calibration_source: "check_in",
      confidence: "media",
      measured_at: 5.minutes.ago,
      factors: ["resposta_check_in"],
      source: "web"
    )

    post "/api/v1/interventions",
         params: { intervention: { tipo: "respiracao_guiada", gatilho: "sobrecarga", duracao_prevista_minutos: 3 } },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_intervention_start" }

    expect(response).to have_http_status(:created)
    intervention = Intervention.find(parsed_body.dig("intervention", "id"))
    expect(parsed_body.dig("intervention", "fim")).to be_nil
    expect(parsed_body.dig("events", 0, "event_type")).to eq("intervencao_iniciada")

    patch "/api/v1/interventions/#{intervention.id}",
          params: { intervention: { feedback: "ajudou" } },
          headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_intervention_finish" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("intervention", "fim")).to be_present
    expect(parsed_body.dig("energy", "estado_qualitativo")).to eq("em_recuperacao")
    expect(parsed_body.dig("energy", "reason_codes")).to include("intervencao_finalizada", "recarga_intervencao", "recuperacao_protegida")
    expect(parsed_body.dig("events").map { |event| event.fetch("event_type") }).to include("intervencao_finalizada", "energia_recalibrada")
    expect(parsed_body.dig("events", 0, "metadata_minima").to_s).not_to include("ajudou")
    expect(response.body).not_to match(/ranking|moeda_virtual|streak/)
  end

  it "normalizes free-form intervention feedback before storing it" do
    user = create_user(email: "intervention-feedback@example.com", name: "Intervention Feedback")
    intervention = user.interventions.create!(
      intervention_type: "pausa_curta",
      trigger: "sobrecarga",
      estimated_minutes: 3,
      started_at: Time.current,
      source: "web"
    )

    patch "/api/v1/interventions/#{intervention.id}",
          params: { intervention: { feedback: "texto livre sensivel demais" } },
          headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_intervention_feedback" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("intervention", "feedback")).to eq("outro")
    expect(response.body).not_to include("texto livre sensivel demais")
  end

  it "does not let another user finish an intervention" do
    owner = create_user(email: "intervention-owner@example.com", name: "Owner")
    other = create_user(email: "intervention-other@example.com", name: "Other")
    intervention = owner.interventions.create!(
      intervention_type: "pausa_curta",
      trigger: "sobrecarga",
      estimated_minutes: 3,
      started_at: Time.current,
      source: "web"
    )

    patch "/api/v1/interventions/#{intervention.id}",
          params: { intervention: { feedback: "ajudou" } },
          headers: { "Cookie" => issue_cookie_for(other), "X-Correlation-ID" => "cor_intervention_cross" }

    expect(response).to have_http_status(:not_found)
    expect(intervention.reload.ended_at).to be_nil
  end

  it "prevents finishing the same intervention twice" do
    user = create_user(email: "intervention-replay@example.com", name: "Replay")
    intervention = user.interventions.create!(
      intervention_type: "pausa_curta",
      trigger: "sobrecarga",
      estimated_minutes: 3,
      started_at: Time.current,
      ended_at: Time.current,
      source: "web"
    )

    expect do
      patch "/api/v1/interventions/#{intervention.id}",
            params: { intervention: { feedback: "ajudou" } },
            headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_intervention_replay" }
    end.not_to change(Energy, :count)

    expect(response).to have_http_status(:conflict)
    expect(parsed_body.dig("error", "code")).to eq("intervention_already_finished")
  end
end
