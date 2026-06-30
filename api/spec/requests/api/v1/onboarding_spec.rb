require "rails_helper"

RSpec.describe "API v1 onboarding", type: :request do
  describe "POST /api/v1/onboarding/complete" do
    it "returns an initial energetic profile, energy, event and first guided action" do
      user = create_user(email: "ana@example.com", name: "Ana")

      post "/api/v1/onboarding/complete",
           params: {
             onboarding: {
               nome: "Ana",
               timezone: "America/Bahia",
               idioma: "pt-BR",
               objetivo_principal: "trabalho",
               janelas_pico: %w[noite],
               janelas_baixa_energia: %w[depois_do_almoco],
               gatilhos: %w[reunioes_longas],
               sensibilidade: "media",
               horario_primeiro_check_in: "08:00",
               horario_ultimo_check_in: "18:00"
             }
           },
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_onboarding_complete_12345" }

      expect(response).to have_http_status(:created)
      expect(parsed_body).to include(
        "onboarding_state" => "onboarding_concluido",
        "correlation_id" => "cor_onboarding_complete_12345",
        "privacy_level" => "sensivel"
      )
      expect(parsed_body.dig("perfil_energetico", "arquetipo")).to eq("Coruja Estrategica")
      expect(parsed_body.dig("energia", "estado_qualitativo")).to eq("media")
      expect(parsed_body.dig("event", "event_type")).to eq("onboarding_concluido")
      expect(parsed_body.dig("first_action", "actions")).to contain_exactly("criar_tarefa", "criar_evento")

      user.reload
      expect(user.onboarding_state).to eq("concluido")
      expect(user.onboarding_progress).to include("current_step" => 6, "total_steps" => 6)
      expect(user.energetic_profiles.last.archetype).to eq("Coruja Estrategica")
      expect(user.energies.last.calibration_source).to eq("onboarding")
      expect(DomainEvent.last.envelope).to include(event_type: "onboarding_concluido", correlation_id: "cor_onboarding_complete_12345")
    end

    it "accepts the contract-shaped web payload without falling back to defaults" do
      user = create_user(email: "web-onboarding@example.com", name: "Web")

      post "/api/v1/onboarding/complete",
           params: {
             version: 1,
             flow_variant: "resumido",
             started_at: "2026-06-14T12:00:00Z",
             completed_at: "2026-06-14T12:03:00Z",
             profile_inputs: {
               nome: "Clara",
               timezone: "America/Sao_Paulo",
               idioma: "pt-BR",
               objetivo_principal: "trabalho",
               janelas_pico: %w[noite],
               janelas_baixa_energia: %w[depois_do_almoco],
               gatilhos: %w[barulho],
               sensibilidade: "alta",
               horario_primeiro_check_in: "08:00",
               horario_ultimo_check_in: "18:00"
             },
             skipped_sensitive_fields: true,
             first_action_requested: true
           },
           as: :json,
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_onboarding_web_payload" }

      expect(response).to have_http_status(:created)
      expect(parsed_body.dig("perfil_energetico", "arquetipo")).to eq("Coruja Estrategica")

      user.reload
      profile = user.energetic_profiles.last
      expect(user.name).to eq("Clara")
      expect(profile.main_goal).to eq("trabalho")
      expect(profile.peak_windows).to eq(%w[noite])
      expect(profile.triggers).to eq(%w[barulho])
      expect(profile.sensitivity).to eq("alta")
    end

    it "stores optional neurodivergence safely without echoing raw values in response or event metadata" do
      user = create_user(email: "bia@example.com", name: "Bia")

      post "/api/v1/onboarding/complete",
           params: {
             onboarding: {
               objetivo_principal: "estudo",
               janelas_pico: %w[manha_cedo],
               identificacoes_neurodivergentes: %w[tdah ahsd]
             }
           },
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_onboarding_neuro_12345" }

      expect(response).to have_http_status(:created)
      expect(user.reload.energetic_profiles.last.neurodivergent_identifications).to eq(%w[tdah ahsd])
      expect(response.body).not_to include("tdah", "ahsd")
      expect(DomainEvent.last.metadata_minima.to_s).not_to include("tdah", "ahsd")
    end
  end

  describe "POST /api/v1/onboarding/skip" do
    it "creates a neutral low-confidence profile and keeps resume available" do
      user = create_user(email: "skip@example.com", name: "Skip")

      post "/api/v1/onboarding/skip",
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_onboarding_skip_12345" }

      expect(response).to have_http_status(:created)
      expect(parsed_body).to include(
        "onboarding_state" => "onboarding_pulado",
        "default_profile_created" => true,
        "resume_available" => true
      )
      expect(parsed_body.dig("energia", "confianca")).to eq("baixa")
      expect(parsed_body.dig("event", "event_type")).to eq("onboarding_pulado")
      expect(user.reload.onboarding_state).to eq("pulado")
      expect(user.energetic_profiles.last.confidence).to eq("baixa")
    end
  end

  describe "PATCH /api/v1/onboarding/progress" do
    it "persists resumable progress without storing raw neurodivergence in progress" do
      user = create_user(email: "progress@example.com", name: "Progress")

      patch "/api/v1/onboarding/progress",
            params: {
              current_step: 3,
              onboarding: {
                objetivo_principal: "trabalho",
                identificacoes_neurodivergentes: %w[tdah]
              }
            },
            headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_onboarding_progress_12345" }

      expect(response).to have_http_status(:ok)
      expect(parsed_body).to include("onboarding_state" => "em_andamento", "resume_available" => true)
      expect(user.reload.onboarding_progress).to include("current_step" => 3, "total_steps" => 6)
      expect(user.onboarding_progress.to_s).not_to include("tdah")
      expect(DomainEvent.last.envelope).to include(event_type: "onboarding_em_andamento", correlation_id: "cor_onboarding_progress_12345")
    end
  end
end
