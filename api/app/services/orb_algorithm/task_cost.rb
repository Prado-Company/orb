module OrbAlgorithm
  class TaskCost
    def initialize(profile:, now:)
      @profile = profile
      @now = now
    end

    def drain(task, energy_state:, heavy_sequence_count: 0)
      weight = task.weight.presence || "medio"
      duration = task.estimated_minutes || OrbAlgorithm::Config::DEFAULT_WINDOW_MINUTES
      raw_drain = base_drain(weight) *
        duration_multiplier(duration) *
        state_multiplier(energy_state) *
        window_multiplier *
        sensitivity_multiplier *
        category_ml_multiplier

      value = raw_drain.round + trigger_penalty(task) + heavy_sequence_penalty(heavy_sequence_count)
      OrbAlgorithm::Config.clamp(value, OrbAlgorithm::Config::TASK_DRAIN_LIMITS.min, OrbAlgorithm::Config::TASK_DRAIN_LIMITS.max)
    end

    private

    attr_reader :profile, :now

    def base_drain(weight)
      OrbAlgorithm::Config::TASK_BASE_DRAIN.fetch(weight, OrbAlgorithm::Config::TASK_BASE_DRAIN.fetch("medio"))
    end

    def duration_multiplier(duration)
      OrbAlgorithm::Config::TASK_DURATION_MULTIPLIERS.find { |max, _multiplier| duration <= max }.last
    end

    def state_multiplier(state)
      OrbAlgorithm::Config::TASK_STATE_MULTIPLIERS.fetch(state, 1.0)
    end

    def window_multiplier
      relation = OrbAlgorithm::TimeWindow.new(profile: profile, now: now).relation
      OrbAlgorithm::Config::WINDOW_MULTIPLIERS.fetch(relation)
    end

    def sensitivity_multiplier
      OrbAlgorithm::Config::SENSITIVITY_MULTIPLIERS.fetch(profile&.sensitivity.to_s, 1.0)
    end

    def category_ml_multiplier
      1.0
    end

    def trigger_penalty(task)
      triggers = Array(profile&.triggers).map(&:to_s)
      penalties = []
      penalties << 4 if triggers.include?("tarefas_sem_comeco") && task.context.blank?
      penalties << 4 if triggers.include?("decisoes_pequenas") && task.weight.in?(%w[medio pesado])
      penalties << 4 if triggers.include?("mensagens_acumuladas") && task.category.to_s == "comunicacao"
      penalties << 4 if triggers.include?("reunioes_longas") && task.category.to_s.match?(/reuniao|reuni/)
      penalties << 4 if triggers.include?("mudancas_ultima_hora") && task.due_on.present? && task.due_on <= Date.current

      [penalties.sum, OrbAlgorithm::Config::MAX_TRIGGER_PENALTY_PER_TASK].min
    end

    def heavy_sequence_penalty(count)
      return 0 if count <= 1
      return 5 if count == 2

      10
    end
  end
end
