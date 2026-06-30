module CheckIns
  class EnergyCalibration
    INACTIVITY_THRESHOLD = 7.days
    RECENT_WINDOW = 2.days

    Result = Data.define(:energy, :event)

    def initialize(user:, source:, correlation_id:, now: Time.current)
      @user = user
      @source = source
      @correlation_id = correlation_id
      @now = now.in_time_zone(ActiveSupport::TimeZone[user.timezone] || Time.zone)
    end

    def from_check_in!(check_in)
      calibration = check_in_calibration(check_in)
      energy = create_energy!(
        calibration: calibration,
        calibration_source: "check_in",
        factors: calibration.fetch(:reason_codes)
      )
      Result.new(energy: energy, event: record_energy_event(energy, long_inactivity: long_inactivity?(check_in)))
    end

    def from_intervention!(intervention)
      calibration = intervention_calibration(intervention)
      energy = create_energy!(
        calibration: calibration,
        calibration_source: "intervencao",
        factors: calibration.fetch(:reason_codes)
      )
      Result.new(energy: energy, event: record_energy_event(energy, long_inactivity: false, intervention: intervention))
    end

    private

    attr_reader :user, :source, :correlation_id, :now

    def create_energy!(calibration:, calibration_source:, factors:)
      user.energies.create!(
        value: calibration.fetch(:value),
        qualitative_state: calibration.fetch(:state),
        calibration_source: calibration_source,
        confidence: calibration.fetch(:confidence),
        measured_at: now,
        factors: factors,
        source: source
      )
    end

    def check_in_calibration(check_in)
      response = check_in.response.to_s
      delta_check_in = OrbAlgorithm::Config::CHECK_IN_DELTAS.fetch(response)
      long_inactivity = long_inactivity?(check_in)
      previous = long_inactivity ? nil : previous_energy
      since = previous&.measured_at || RECENT_WINDOW.ago(now)
      previous_value = previous&.value || OrbAlgorithm::Config::DEFAULT_ENERGY_VALUE
      previous_state = previous&.qualitative_state || "media"
      task_drain = completed_task_drain(since: since, previous_state: previous_state)
      event_drain = past_event_drain(since: since)
      recovery_gain = finished_intervention_gain(since: since)
      passive_adjustment = passive_adjustment_for_profile
      value = OrbAlgorithm::Config.clamp(
        previous_value + delta_check_in + recovery_gain - task_drain - event_drain + passive_adjustment,
        0,
        100
      )
      signals = OrbAlgorithm::Signals.new(user: user, now: now)
      overload_score = signals.overload_score
      recovery_mode = signals.recovery_mode_active?
      state = determine_state(value: value, overload_score: overload_score, recovery_mode: recovery_mode)

      {
        value: value,
        state: state,
        confidence: confidence_for(last_check_in: check_in, long_inactivity: long_inactivity),
        reason_codes: check_in_reason_codes(
          check_in: check_in,
          long_inactivity: long_inactivity,
          task_drain: task_drain,
          event_drain: event_drain,
          recovery_gain: recovery_gain,
          passive_adjustment: passive_adjustment,
          overload_score: overload_score,
          recovery_mode: recovery_mode,
          overload_reason_codes: signals.overload_reason_codes
        )
      }
    end

    def intervention_calibration(intervention)
      previous = previous_energy
      previous_value = previous&.value || 45
      recovery_gain = intervention_recovery_gain(intervention)
      value = OrbAlgorithm::Config.clamp(previous_value + recovery_gain, 0, 100)
      {
        value: value,
        state: "em_recuperacao",
        confidence: "media",
        reason_codes: [
          "intervencao_finalizada",
          "recarga_intervencao",
          "recuperacao_protegida",
          "recarga_#{intervention.intervention_type}"
        ].uniq
      }
    end

    def completed_task_drain(since:, previous_state:)
      heavy_sequence_count = 0
      cost = OrbAlgorithm::TaskCost.new(profile: energetic_profile, now: now)

      user.tasks.active
        .where(status: "concluido", updated_at: since..now)
        .order(:updated_at)
        .sum do |task|
          heavy_sequence_count += 1 if task.weight == "pesado"
          cost.drain(task, energy_state: previous_state, heavy_sequence_count: heavy_sequence_count)
        end
    end

    def past_event_drain(since:)
      cost = OrbAlgorithm::EventCost.new(profile: energetic_profile, now: now)
      user.events.active
        .where.not(status: "cancelado")
        .where(ends_at: since..now)
        .sum { |event| cost.drain(event) }
    end

    def finished_intervention_gain(since:)
      user.interventions.where(ended_at: since..now).sum { |intervention| intervention_recovery_gain(intervention) }
    end

    def intervention_recovery_gain(intervention)
      minutes = intervention.estimated_minutes.to_i

      case intervention.intervention_type
      when "respiracao_guiada"
        minutes <= 2 ? 4 : 8
      when "pausa_curta"
        return 4 if minutes <= 3
        return 6 if minutes <= 5
        return 10 if minutes <= 10

        12
      when "audio_regulacao"
        return 5 if minutes <= 3
        return 8 if minutes <= 7

        12
      when "grounding_rapido", "reduzir_estimulo_externo"
        6
      when "organizacao_ambiente"
        5
      else
        6
      end
    end

    def passive_adjustment_for_profile
      case OrbAlgorithm::TimeWindow.new(profile: energetic_profile, now: now).relation
      when :peak then 4
      when :low then -4
      else 0
      end
    end

    def determine_state(value:, overload_score:, recovery_mode:)
      thresholds = OrbAlgorithm::Config::ENERGY_THRESHOLDS
      return "em_sobrecarga" if overload_score >= thresholds.fetch(:overload_score_min) || value <= thresholds.fetch(:overload_energy_max)
      return "em_recuperacao" if recovery_mode
      return "baixa" if value <= thresholds.fetch(:low_max)
      return "media" if value <= thresholds.fetch(:medium_max)

      "alta"
    end

    def confidence_for(last_check_in:, long_inactivity:)
      return "baixa" if long_inactivity

      answered_at = last_check_in.answered_at || now
      age = now - answered_at
      return "alta" if age < 3.hours
      return "media" if age < 8.hours && recent_activity?

      "baixa"
    end

    def check_in_reason_codes(check_in:, long_inactivity:, task_drain:, event_drain:, recovery_gain:, passive_adjustment:, overload_score:, recovery_mode:, overload_reason_codes:)
      codes = [
        "resposta_check_in",
        "delta_check_in_#{check_in.response}",
        "motor_deterministico_v1"
      ]

      if long_inactivity
        codes += %w[padroes_historicos longa_inatividade]
      else
        codes << "tarefas_recentes" if user.tasks.active.where(updated_at: RECENT_WINDOW.ago(now)..now).exists?
        codes << "eventos_recentes" if user.events.active.where(starts_at: RECENT_WINDOW.ago(now)..(now + RECENT_WINDOW)).exists?
        codes << "historico_recente"
      end

      codes << "drenagem_tarefas_recentes" if task_drain.positive?
      codes << "drenagem_eventos_recentes" if event_drain.positive?
      codes << "recarga_intervencoes_recentes" if recovery_gain.positive?
      codes << "janela_pico_declarada" if passive_adjustment.positive?
      codes << "janela_baixa_declarada" if passive_adjustment.negative?
      codes << "recovery_mode_ativo" if recovery_mode
      codes << "overload_score_ativo" if overload_score >= OrbAlgorithm::Config::ENERGY_THRESHOLDS.fetch(:overload_score_min)
      (codes + overload_reason_codes).uniq
    end

    def previous_energy
      @previous_energy ||= user.energies.order(measured_at: :desc).first
    end

    def energetic_profile
      @energetic_profile ||= user.energetic_profile
    end

    def recent_activity?
      user.tasks.active.where(updated_at: RECENT_WINDOW.ago(now)..now).exists? ||
        user.events.active.where(starts_at: RECENT_WINDOW.ago(now)..(now + RECENT_WINDOW)).exists?
    end

    def long_inactivity?(check_in)
      previous_check_in = user.check_ins
        .where.not(id: check_in.id)
        .where.not(answered_at: nil)
        .order(answered_at: :desc)
        .first

      previous_check_in.present? && previous_check_in.answered_at < now - INACTIVITY_THRESHOLD
    end

    def record_energy_event(energy, long_inactivity:, intervention: nil)
      Foundation::EventRecorder.record_event(
        event_type: "energia_recalibrada",
        actor: { type: "usuario", id: user.id.to_s },
        resource: { type: "energia", id: energy.id.to_s },
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel",
        metadata_minima: {
          energia_estado_resultante: energy.qualitative_state,
          fonte_calibracao: energy.calibration_source,
          confianca: energy.confidence,
          fatores_count: energy.factors.length,
          reason_codes: energy.factors,
          long_inactivity: long_inactivity,
          intervention_id: intervention&.id&.to_s
        }.compact
      )
    end
  end
end
