module Onboarding
  class SkipFlow
    DEFAULT_RESPONSES = {
      objetivo_principal: "rotina_geral",
      janelas_pico: [],
      janelas_baixa_energia: [],
      gatilhos: [],
      sensibilidade: "media",
      tom_preferido: "acolhedor",
      intensidade_notificacao: "equilibrado",
      horario_primeiro_check_in: "08:00",
      horario_ultimo_check_in: "18:00"
    }.freeze

    def initialize(user:, source:, correlation_id:)
      @user = user
      @source = source
      @correlation_id = correlation_id
    end

    def call
      ActiveRecord::Base.transaction do
        now = Time.current
        built_profile = BuildInitialProfile.new(user: user, responses: DEFAULT_RESPONSES, source: source).call
        user.update!(
          onboarding_state: "pulado",
          onboarding_progress: progress_payload(built_profile),
          onboarding_started_at: user.onboarding_started_at || now,
          onboarding_skipped_at: now,
          onboarding_profile_version: user.onboarding_profile_version + 1
        )

        profile = user.energetic_profiles.create!(built_profile.attributes)
        energy = user.energies.create!(
          value: 50,
          qualitative_state: "media",
          calibration_source: "onboarding",
          confidence: "baixa",
          measured_at: now,
          factors: %w[perfil_provisorio motor_deterministico_v1],
          source: source
        )
        event = Foundation::EventRecorder.record_event(
          event_type: "onboarding_pulado",
          actor: { type: "usuario", id: user.id.to_s },
          resource: { type: "perfil_energetico", id: profile.id.to_s },
          source: source,
          correlation_id: correlation_id,
          privacy_level: "sensivel",
          metadata_minima: {
            skip_reason: "explorar_primeiro",
            flow_variant: "resumido",
            default_profile_created: true,
            resume_available: true,
            profile_confidence: "baixa",
            decision_engine: "deterministico",
            llm_used: false
          }
        )

        ResponseSerializer.new(
          user: user,
          profile: profile,
          energy: energy,
          event: event,
          source: source,
          correlation_id: correlation_id,
          onboarding_state: user.onboarding_state
        ).skip_payload
      end
    end

    private

    attr_reader :user, :source, :correlation_id

    def progress_payload(built_profile)
      {
        current_step: 1,
        total_steps: 6,
        flow_variant: "resumido",
        skipped_at: Time.current.utc.iso8601,
        default_profile_created: true,
        resume_available: true,
        perfil_energetico_inicial: built_profile.payload.except(:identificacoes_neurodivergentes)
      }
    end
  end
end
