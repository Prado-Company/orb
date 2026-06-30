module Onboarding
  class CompleteFlow
    def initialize(user:, responses:, source:, correlation_id:)
      @user = user
      @responses = responses.deep_symbolize_keys
      @source = source
      @correlation_id = correlation_id
    end

    def call
      ActiveRecord::Base.transaction do
        built_profile = BuildInitialProfile.new(user: user, responses: responses, source: source).call
        now = Time.current
        user.update!(
          name: responses[:nome].presence || user.name,
          pronouns: responses[:pronomes].presence || user.pronouns,
          timezone: responses[:timezone].presence || user.timezone,
          locale: responses[:idioma].presence || user.locale,
          onboarding_state: "concluido",
          onboarding_progress: progress_payload(built_profile),
          onboarding_started_at: user.onboarding_started_at || now,
          onboarding_completed_at: now,
          onboarding_profile_version: user.onboarding_profile_version + 1
        )

        profile = user.energetic_profiles.create!(built_profile.attributes)
        energy = user.energies.create!(
          value: initial_energy_value(profile),
          qualitative_state: "media",
          calibration_source: "onboarding",
          confidence: built_profile.confidence,
          measured_at: now,
          factors: %w[perfil_inicial motor_deterministico_v1],
          source: source
        )
        event = record_event(
          "onboarding_concluido",
          profile,
          metadata_minima: {
            flow_variant: "resumido",
            profile_confidence: profile.confidence,
            neurodivergence_declared: profile.neurodivergent_identifications.any?,
            decision_engine: "deterministico",
            llm_used: false,
            skipped_sensitive_fields: built_profile.skipped_sensitive_fields,
            first_action_offered: true
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
        ).complete_payload
      end
    end

    private

    attr_reader :user, :responses, :source, :correlation_id

    def progress_payload(built_profile)
      Foundation::LogSanitizer.redact(
        current_step: 6,
        total_steps: 6,
        flow_variant: "resumido",
        responses: responses.except(:identificacoes_neurodivergentes),
        perfil_energetico_inicial: built_profile.payload
      )
    end

    def initial_energy_value(profile)
      return 55 if profile.confidence == "baixa"
      return 58 if profile.sensitivity == "alta"

      60
    end

    def record_event(event_type, profile, metadata_minima:)
      Foundation::EventRecorder.record_event(
        event_type: event_type,
        actor: { type: "usuario", id: user.id.to_s },
        resource: { type: "perfil_energetico", id: profile.id.to_s },
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel",
        metadata_minima: metadata_minima
      )
    end
  end
end
