module OrbAlgorithm
  module Config
    ENERGY_THRESHOLDS = {
      overload_energy_max: 15,
      low_max: 35,
      medium_max: 64,
      overload_score_min: 60
    }.freeze

    CHECK_IN_DELTAS = {
      "muito_baixo" => -25,
      "baixo" => -20,
      "neutro" => 0,
      "bom" => 5,
      "alto" => 10
    }.freeze

    TASK_BASE_DRAIN = {
      "leve" => 5,
      "medio" => 12,
      "pesado" => 22
    }.freeze

    TASK_DURATION_MULTIPLIERS = [
      [15, 0.70],
      [45, 1.00],
      [90, 1.25],
      [Float::INFINITY, 1.50]
    ].freeze

    TASK_STATE_MULTIPLIERS = {
      "alta" => 0.90,
      "media" => 1.00,
      "baixa" => 1.25,
      "em_recuperacao" => 1.30,
      "em_sobrecarga" => 1.50
    }.freeze

    WINDOW_MULTIPLIERS = {
      peak: 0.85,
      neutral: 1.00,
      low: 1.20
    }.freeze

    SENSITIVITY_MULTIPLIERS = {
      "baixa" => 0.95,
      "media" => 1.00,
      "alta" => 1.10
    }.freeze

    TASK_DRAIN_LIMITS = (2..35).freeze
    MAX_TRIGGER_PENALTY_PER_TASK = 12
    TASK_SCORE_THRESHOLD = 35

    SCORE_DEADLINE = {
      overdue: 45,
      today: 35,
      next_2_days: 25,
      next_7_days: 15,
      none: 5
    }.freeze

    SCORE_ENERGY_COMPATIBILITY = {
      "alta" => { "leve" => 14, "medio" => 22, "pesado" => 30 },
      "media" => { "leve" => 25, "medio" => 30, "pesado_curta" => 18, "pesado_longa" => 8 },
      "baixa" => { "leve" => 30, "medio_curta" => 12, "medio_longa" => 0, "pesado" => 0 }
    }.freeze

    EVENT_BASE_DRAIN = [
      [30, 4],
      [60, 8],
      [120, 15],
      [Float::INFINITY, 25]
    ].freeze

    OVERLOAD = {
      negative_streak_2: 25,
      negative_streak_3: 40,
      heavy_task_recent: 15,
      heavy_task_recent_max: 30,
      trigger_day: 10,
      trigger_day_max: 30,
      event_60_120_recent: 10,
      event_over_120_recent: 20,
      repeated_postponement: 15,
      no_recovery_6h: 10
    }.freeze

    DEFAULT_ENERGY_VALUE = 55
    DEFAULT_WINDOW_MINUTES = 120

    module_function

    def clamp(value, min, max)
      [[value, min].max, max].min
    end
  end
end
