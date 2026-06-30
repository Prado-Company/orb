module Suggestions
  class NextAction
    ACTIONS_AVAILABLE = %w[comecar adiar trocar].freeze
    REGULATION_STATES = %w[em_sobrecarga em_recuperacao].freeze

    Result = Data.define(:suggestion, :payload)
    ScoredTask = Data.define(:task, :score, :drain, :reason_codes, :score_components)

    def initialize(user:, source:, correlation_id:, now: Time.current)
      @user = user
      @source = source
      @correlation_id = correlation_id
      @now = now.in_time_zone(ActiveSupport::TimeZone[user.timezone] || Time.zone)
    end

    def call
      current_energy = latest_energy
      event_context = build_event_context
      available_window = available_window_minutes(event_context)
      decision = decision_for(current_energy, available_window, event_context)
      suggestion = user.suggestions.create!(
        suggested_item_type: decision.fetch(:resource).fetch(:type),
        suggested_item_id: numeric_resource_id(decision.fetch(:resource).fetch(:id)),
        reason: decision.fetch(:reason),
        available_actions: ACTIONS_AVAILABLE,
        summarized_input: summarized_input(current_energy, available_window, decision),
        source: source,
        privacy_level: "sensivel"
      )

      Result.new(suggestion: suggestion, payload: payload_for(suggestion, decision, current_energy, available_window))
    end

    private

    attr_reader :user, :source, :correlation_id, :now

    def decision_for(energy, available_window, event_context)
      signals = OrbAlgorithm::Signals.new(user: user, now: now)
      overload_score = signals.overload_score
      recovery_mode = signals.recovery_mode_active?
      effective_state = effective_state_for(energy, overload_score, recovery_mode)

      return current_event_decision(event_context.fetch(:current_event), energy, available_window, overload_score) if event_context.fetch(:current_event)
      return preparation_decision(event_context.fetch(:next_event), energy, available_window, overload_score) if event_starts_soon?(event_context.fetch(:next_event), minutes: 10)
      return regulation_decision(energy, effective_state, available_window, overload_score, signals.overload_reason_codes) if REGULATION_STATES.include?(effective_state)

      scored = scored_tasks(energy_state: effective_state, available_window: available_window)
      selected = selected_task(scored)
      return task_decision(selected, effective_state, available_window, overload_score) if selected

      {
        action_type: "trocar",
        resource: { type: "tarefa", id: "nova" },
        reason: "Nenhuma tarefa ativa ficou segura para a janela atual; vale criar um passo menor ou fazer uma pausa curta.",
        task_weight: nil,
        candidate_count: active_tasks.count,
        score: nil,
        predicted_drain: nil,
        overload_score_band: overload_score_band(overload_score),
        reason_codes: ["nenhuma_tarefa_elegivel", "motor_deterministico_v1"],
        score_components: {}
      }
    end

    def task_decision(scored_task, energy_state, available_window, overload_score)
      task = scored_task.task
      {
        action_type: "comecar",
        resource: { type: "tarefa", id: task.id.to_s },
        reason: reason_for(scored_task, energy_state, available_window),
        task_weight: task.weight,
        candidate_count: active_tasks.count,
        score: scored_task.score,
        predicted_drain: scored_task.drain,
        overload_score_band: overload_score_band(overload_score),
        reason_codes: scored_task.reason_codes,
        score_components: scored_task.score_components
      }
    end

    def regulation_decision(energy, effective_state, available_window, overload_score, overload_reason_codes)
      message =
        if effective_state == "em_sobrecarga"
          "regulacao vem antes das tarefas neste momento; comece por uma pausa curta."
        else
          "regulacao protegida neste momento; retome tarefas depois da pausa."
        end

      {
        action_type: "regular",
        resource: { type: "intervencao", id: "nova" },
        reason: message,
        task_weight: nil,
        candidate_count: active_tasks.count,
        score: nil,
        predicted_drain: nil,
        overload_score_band: overload_score_band(overload_score),
        reason_codes: (["estado_#{effective_state}", "regulacao_antes_de_tarefa", "motor_deterministico_v1"] + overload_reason_codes).uniq,
        score_components: {
          energia_valor: energy.value,
          janela_disponivel_minutos: available_window
        }
      }
    end

    def current_event_decision(event, energy, available_window, overload_score)
      {
        action_type: "acompanhar_evento",
        resource: { type: "evento", id: event.id.to_s },
        reason: "Existe um evento em andamento; o Orb nao vai competir com ele com uma tarefa nova.",
        task_weight: nil,
        candidate_count: active_tasks.count,
        score: nil,
        predicted_drain: nil,
        overload_score_band: overload_score_band(overload_score),
        reason_codes: ["evento_atual", "bloqueio_pre_score", "motor_deterministico_v1"],
        score_components: {
          energia_valor: energy.value,
          janela_disponivel_minutos: available_window
        }
      }
    end

    def preparation_decision(event, energy, available_window, overload_score)
      {
        action_type: "preparar_evento",
        resource: { type: "evento", id: event.id.to_s },
        reason: "O proximo evento esta perto; melhor preparar a transicao ou fazer uma pausa curta.",
        task_weight: nil,
        candidate_count: active_tasks.count,
        score: nil,
        predicted_drain: nil,
        overload_score_band: overload_score_band(overload_score),
        reason_codes: ["evento_comeca_em_ate_10_min", "bloqueio_pre_score", "motor_deterministico_v1"],
        score_components: {
          energia_valor: energy.value,
          janela_disponivel_minutos: available_window
        }
      }
    end

    def scored_tasks(energy_state:, available_window:)
      active_tasks.filter_map do |task|
        next unless task_eligible?(task, energy_state, available_window)

        score_task(task, energy_state: energy_state, available_window: available_window)
      end
    end

    def selected_task(scored_tasks)
      selected = scored_tasks.max_by { |item| [item.score, -due_sort_value(item.task), -weight_rank(item.task.weight), -item.task.created_at.to_i] }
      return selected if selected&.score.to_i >= OrbAlgorithm::Config::TASK_SCORE_THRESHOLD

      scored_tasks
        .select { |item| item.task.weight == "leve" && task_duration(item.task) <= 15 }
        .max_by(&:score)
    end

    def task_eligible?(task, energy_state, available_window)
      return false if REGULATION_STATES.include?(energy_state)

      weight = task.weight.presence || "medio"
      duration = task_duration(task)
      return false if duration > available_window * 1.2
      return false if available_window < 15 && !(weight == "leve" && duration <= 15)
      return false if energy_state == "baixa" && weight == "pesado"
      return false if energy_state == "baixa" && weight == "medio" && duration > 45

      true
    end

    def score_task(task, energy_state:, available_window:)
      drain = task_cost.drain(task, energy_state: energy_state, heavy_sequence_count: recent_heavy_task_count + (task.weight == "pesado" ? 1 : 0))
      components = {
        prazo: deadline_score(task),
        compatibilidade_energia: energy_compatibility_score(task, energy_state),
        janela_disponivel: available_window_score(task, available_window),
        contexto_categoria: context_score(task),
        status: status_score(task),
        ajuste_ml: 0,
        penalidade_drenagem: -(drain * 0.5).round,
        penalidade_cooldown: -cooldown_penalty(task)
      }
      score = components.values.sum

      ScoredTask.new(
        task: task,
        score: score,
        drain: drain,
        reason_codes: reason_codes_for_task(task, energy_state, available_window, score, drain),
        score_components: components
      )
    end

    def active_tasks
      @active_tasks ||= user.tasks.active.where.not(status: "concluido").order(:due_on, :created_at).to_a
    end

    def build_event_context
      current_event = user.events.active
        .where.not(status: "cancelado")
        .where("starts_at <= ? AND ends_at > ?", now, now)
        .order(:starts_at)
        .first
      next_event = user.events.active
        .where.not(status: "cancelado")
        .where("starts_at > ?", now)
        .order(:starts_at)
        .first

      { current_event: current_event, next_event: next_event }
    end

    def available_window_minutes(event_context)
      next_event = event_context.fetch(:next_event)
      return OrbAlgorithm::Config::DEFAULT_WINDOW_MINUTES unless next_event

      [((next_event.starts_at - now) / 60).floor, 0].max
    end

    def latest_energy
      user.energies.order(measured_at: :desc).first || fallback_energy
    end

    def fallback_energy
      Energy.new(
        user: user,
        value: OrbAlgorithm::Config::DEFAULT_ENERGY_VALUE,
        qualitative_state: "media",
        calibration_source: "historico",
        confidence: "baixa",
        measured_at: now,
        factors: %w[padroes_historicos],
        source: source
      )
    end

    def effective_state_for(energy, overload_score, recovery_mode)
      thresholds = OrbAlgorithm::Config::ENERGY_THRESHOLDS
      return "em_sobrecarga" if overload_score >= thresholds.fetch(:overload_score_min) || energy.value <= thresholds.fetch(:overload_energy_max)
      return "em_recuperacao" if recovery_mode || energy.qualitative_state == "em_recuperacao"

      energy.qualitative_state
    end

    def event_starts_soon?(event, minutes:)
      event.present? && event.starts_at <= now + minutes.minutes
    end

    def reason_for(scored_task, energy_state, available_window)
      "Cabe na janela atual de #{available_window} minutos; score #{scored_task.score} e drenagem prevista #{scored_task.drain} dentro das regras do servidor para energia #{energy_state}."
    end

    def summarized_input(energy, available_window, decision)
      {
        energia_estado: energy.qualitative_state,
        janela_disponivel_minutos: available_window,
        tarefas_candidatas_count: decision.fetch(:candidate_count),
        task_weight: decision[:task_weight],
        regulation_protected: decision.fetch(:action_type) == "regular",
        score: decision[:score],
        drenagem_prevista: decision[:predicted_drain],
        overload_score_band: decision[:overload_score_band],
        reason_codes: decision.fetch(:reason_codes),
        score_components: decision.fetch(:score_components),
        rule_version: "orb_algorithm_v1",
        decision_engine: "deterministico",
        llm_used: false
      }.compact
    end

    def payload_for(suggestion, decision, energy, available_window)
      {
        version: 1,
        suggestion_id: suggestion.id.to_s,
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel",
        decision_engine: "deterministico",
        action: {
          type: decision.fetch(:action_type),
          resource: decision.fetch(:resource)
        },
        reason: decision.fetch(:reason),
        reason_codes: decision.fetch(:reason_codes),
        score: decision[:score],
        drenagem_prevista: decision[:predicted_drain],
        actions_available: ACTIONS_AVAILABLE,
        explanation_inputs: {
          energia_estado: energy.qualitative_state,
          janela_disponivel_minutos: available_window,
          task_weight: decision[:task_weight],
          score: decision[:score],
          drenagem_prevista: decision[:predicted_drain],
          overload_score_band: decision[:overload_score_band],
          reason_codes: decision.fetch(:reason_codes),
          score_components: decision.fetch(:score_components)
        },
        llm_used: false,
        fallback_available: true
      }
    end

    def numeric_resource_id(id)
      id.to_s.match?(/\A\d+\z/) ? id : nil
    end

    def task_cost
      @task_cost ||= OrbAlgorithm::TaskCost.new(profile: energetic_profile, now: now)
    end

    def energetic_profile
      @energetic_profile ||= user.energetic_profile
    end

    def task_duration(task)
      task.estimated_minutes || OrbAlgorithm::Config::DEFAULT_WINDOW_MINUTES
    end

    def deadline_score(task)
      return OrbAlgorithm::Config::SCORE_DEADLINE.fetch(:none) unless task.due_on
      return OrbAlgorithm::Config::SCORE_DEADLINE.fetch(:overdue) if task.due_on < Date.current
      return OrbAlgorithm::Config::SCORE_DEADLINE.fetch(:today) if task.due_on == Date.current
      return OrbAlgorithm::Config::SCORE_DEADLINE.fetch(:next_2_days) if task.due_on <= 2.days.from_now.to_date
      return OrbAlgorithm::Config::SCORE_DEADLINE.fetch(:next_7_days) if task.due_on <= 7.days.from_now.to_date

      OrbAlgorithm::Config::SCORE_DEADLINE.fetch(:none)
    end

    def energy_compatibility_score(task, energy_state)
      weight = task.weight.presence || "medio"
      duration = task_duration(task)
      table = OrbAlgorithm::Config::SCORE_ENERGY_COMPATIBILITY

      case [energy_state, weight]
      when ["media", "pesado"]
        table.fetch("media").fetch(duration <= 45 ? "pesado_curta" : "pesado_longa")
      when ["baixa", "medio"]
        table.fetch("baixa").fetch(duration <= 45 ? "medio_curta" : "medio_longa")
      else
        table.fetch(energy_state, {}).fetch(weight, 0)
      end
    end

    def available_window_score(task, available_window)
      duration = task_duration(task)
      return 20 if duration <= available_window * 0.8
      return 15 if duration <= available_window
      return 8 if duration <= available_window * 1.2

      0
    end

    def context_score(task)
      score = 0
      score += 5 if energetic_profile&.main_goal.present? && task.category.to_s == energetic_profile.main_goal
      score += 3 if task.context.present?
      score -= 5 if task.context.blank?
      score
    end

    def status_score(task)
      case task.status
      when "em_progresso" then 8
      when "iniciado" then 5
      when "adiado" then -10
      else 0
      end
    end

    def cooldown_penalty(task)
      return 10 if task.status == "adiado"

      recent_exchange_for_task?(task) ? 10 : 0
    end

    def recent_exchange_for_task?(task)
      DomainEvent.where(
        event_type: "sugestao_trocada",
        actor_type: "usuario",
        actor_id: user.id.to_s,
        resource_type: "sugestao",
        occurred_at: 4.hours.ago(now)..now
      ).where("metadata_minima ->> 'suggested_item_id' = ?", task.id.to_s).exists?
    end

    def reason_codes_for_task(task, energy_state, available_window, score, drain)
      codes = ["motor_deterministico_v1"]
      codes << "deadline_overdue" if task.due_on.present? && task.due_on < Date.current
      codes << "deadline_today" if task.due_on == Date.current
      codes << "deadline_soon" if task.due_on.present? && task.due_on <= 2.days.from_now.to_date
      codes << "fits_available_window" if task_duration(task) <= available_window
      codes << "starts_only_fits_window" if task_duration(task) > available_window && task_duration(task) <= available_window * 1.2
      codes << "compatible_with_#{energy_state}_energy"
      codes << "low_predicted_drain" if drain <= 10
      codes << "medium_predicted_drain" if drain.between?(11, 22)
      codes << "high_predicted_drain" if drain > 22
      codes << "score_above_threshold" if score >= OrbAlgorithm::Config::TASK_SCORE_THRESHOLD
      codes << "task_has_clear_start" if task.context.present?
      codes << "task_needs_micro_step_future" if task.context.blank?
      codes.uniq
    end

    def recent_heavy_task_count
      @recent_heavy_task_count ||= user.tasks.active
        .where(status: "concluido", weight: "pesado", updated_at: 4.hours.ago(now)..now)
        .count
    end

    def overload_score_band(score)
      return "normal" if score < 45
      return "atencao" if score < OrbAlgorithm::Config::ENERGY_THRESHOLDS.fetch(:overload_score_min)

      "sobrecarga"
    end

    def due_sort_value(task)
      (task.due_on || Date.new(9999, 12, 31)).to_time.to_i
    end

    def due_rank(task)
      task.due_on || Date.new(9999, 12, 31)
    end

    def weight_rank(weight)
      { "leve" => 0, "medio" => 1, "pesado" => 2 }.fetch(weight, 1)
    end
  end
end
