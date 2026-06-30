module Onboarding
  class ResponseSerializer
    def initialize(user:, profile:, energy:, event:, source:, correlation_id:, onboarding_state:)
      @user = user
      @profile = profile
      @energy = energy
      @event = event
      @source = source
      @correlation_id = correlation_id
      @onboarding_state = onboarding_state
    end

    def complete_payload
      base_payload.merge(
        onboarding_state: "onboarding_concluido",
        perfil_energetico: profile_payload,
        energia: energy_payload,
        event: event,
        first_action: first_action_payload
      )
    end

    def skip_payload
      base_payload.merge(
        onboarding_state: "onboarding_pulado",
        perfil_energetico: profile_payload,
        energia: energy_payload,
        event: event,
        default_profile_created: true,
        resume_available: true,
        defaults: {
          objetivo_principal: profile.main_goal,
          janelas_pico: profile.peak_windows,
          gatilhos: profile.triggers,
          tom_preferido: profile.preferred_tone,
          sensibilidade: profile.sensitivity,
          intensidade_notificacao: profile.notification_intensity,
          horario_primeiro_check_in: profile.first_check_in_time,
          horario_ultimo_check_in: profile.last_check_in_time,
          energia_inicial: {
            estado_qualitativo: energy.qualitative_state,
            confianca: energy.confidence
          }
        },
        first_action: first_action_payload
      )
    end

    def status_payload
      base_payload.merge(
        onboarding_state: onboarding_state,
        progress: Foundation::LogSanitizer.redact(user.onboarding_progress),
        resume_available: %w[em_andamento pulado revisao_solicitada].include?(user.onboarding_state),
        perfil_energetico: profile && profile_payload,
        energia: energy && energy_payload,
        first_action: first_action_payload
      ).compact
    end

    private

    attr_reader :user, :profile, :energy, :event, :source, :correlation_id, :onboarding_state

    def base_payload
      {
        version: 1,
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel"
      }
    end

    def profile_payload
      {
        version: 1,
        usuario_id: user.id.to_s,
        arquetipo: profile.archetype,
        objetivo_principal: profile.main_goal,
        janelas_pico: profile.peak_windows,
        janelas_baixa_energia: profile.low_energy_windows,
        gatilhos: profile.triggers,
        identificacoes_neurodivergentes: [],
        tom_preferido: profile.preferred_tone,
        sensibilidade: profile.sensitivity,
        intensidade_notificacao: profile.notification_intensity,
        horario_primeiro_check_in: profile.first_check_in_time,
        horario_ultimo_check_in: profile.last_check_in_time,
        horarios_refeicoes: profile.meal_times,
        pausas_protegidas: profile.protected_breaks,
        confianca: profile.confidence,
        data_onboarding: profile.created_at.utc.iso8601,
        decision_engine: "deterministico",
        llm_used: false,
        source: profile.source,
        privacy_level: "sensivel",
        updated_at: profile.updated_at.utc.iso8601
      }
    end

    def energy_payload
      {
        version: 1,
        usuario_id: user.id.to_s,
        valor: energy.value,
        estado_qualitativo: energy.qualitative_state,
        fonte_calibracao: energy.calibration_source,
        confianca: energy.confidence,
        timestamp: energy.measured_at.utc.iso8601,
        fatores: energy.factors,
        reason_codes: energy.factors,
        source: energy.source,
        privacy_level: "sensivel"
      }
    end

    def first_action_payload
      {
        type: "create_first_task_or_event",
        status: "offered",
        actions: %w[criar_tarefa criar_evento],
        primary_label: "Criar tarefa",
        secondary_label: "Criar evento"
      }
    end
  end
end
