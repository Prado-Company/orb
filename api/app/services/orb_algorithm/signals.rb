module OrbAlgorithm
  class Signals
    RECENT_HEAVY_TASK_WINDOW = 4.hours
    RECENT_EVENT_WINDOW = 2.hours
    RECOVERY_WINDOW = 30.minutes
    ROUTINE_RECOVERY_GAP = 6.hours

    def initialize(user:, now:)
      @user = user
      @now = now
      @profile = user.energetic_profile
    end

    def overload_score
      [
        negative_check_in_streak_score,
        heavy_tasks_score,
        trigger_day_score,
        recent_long_events_score,
        repeated_postponement_score,
        no_recovery_score
      ].sum
    end

    def overload_reason_codes
      codes = []
      codes << "check_ins_negativos_recentes" if negative_check_in_streak_score.positive?
      codes << "tarefas_pesadas_recentes" if heavy_tasks_score.positive?
      codes << "gatilhos_do_dia" if trigger_day_score.positive?
      codes << "eventos_longos_recentes" if recent_long_events_score.positive?
      codes << "adiamentos_repetidos" if repeated_postponement_score.positive?
      codes << "sem_recuperacao_6h" if no_recovery_score.positive?
      codes
    end

    def recovery_mode_active?
      recent_recovery? || in_declared_meal_or_break?
    end

    private

    attr_reader :user, :now, :profile

    def negative_check_in_streak_score
      streak = user.check_ins.where.not(answered_at: nil).order(answered_at: :desc).limit(3).take_while do |check_in|
        check_in.response.in?(%w[muito_baixo baixo])
      end.length

      return OrbAlgorithm::Config::OVERLOAD.fetch(:negative_streak_3) if streak >= 3
      return OrbAlgorithm::Config::OVERLOAD.fetch(:negative_streak_2) if streak == 2

      0
    end

    def heavy_tasks_score
      count = user.tasks.active
        .where(status: "concluido", weight: "pesado", updated_at: (now - RECENT_HEAVY_TASK_WINDOW)..now)
        .count
      [count * OrbAlgorithm::Config::OVERLOAD.fetch(:heavy_task_recent),
       OrbAlgorithm::Config::OVERLOAD.fetch(:heavy_task_recent_max)].min
    end

    def trigger_day_score
      return 0 if Array(profile&.triggers).blank?
      return 0 unless activity_today?

      [Array(profile.triggers).count * OrbAlgorithm::Config::OVERLOAD.fetch(:trigger_day),
       OrbAlgorithm::Config::OVERLOAD.fetch(:trigger_day_max)].min
    end

    def recent_long_events_score
      user.events.active
        .where(ends_at: (now - RECENT_EVENT_WINDOW)..now)
        .sum do |event|
          duration = ((event.ends_at - event.starts_at) / 60).ceil
          if duration > 120
            OrbAlgorithm::Config::OVERLOAD.fetch(:event_over_120_recent)
          elsif duration > 60
            OrbAlgorithm::Config::OVERLOAD.fetch(:event_60_120_recent)
          else
            0
          end
        end
    end

    def repeated_postponement_score
      repeated_task = DomainEvent
        .where(event_type: "tarefa_adiada", actor_type: "usuario", actor_id: user.id.to_s, occurred_at: now.beginning_of_day..now)
        .group(:resource_id)
        .count
        .values
        .any? { |count| count >= 3 }

      repeated_check_in = user.check_ins.where("postponements >= ?", 2).where(updated_at: now.beginning_of_day..now).exists?
      repeated_task || repeated_check_in ? OrbAlgorithm::Config::OVERLOAD.fetch(:repeated_postponement) : 0
    end

    def no_recovery_score
      return 0 unless routine_active?
      return 0 if user.interventions.where(ended_at: (now - ROUTINE_RECOVERY_GAP)..now).exists?

      OrbAlgorithm::Config::OVERLOAD.fetch(:no_recovery_6h)
    end

    def activity_today?
      user.tasks.active.where(updated_at: now.beginning_of_day..now).exists? ||
        user.events.active.where(starts_at: now.beginning_of_day..now.end_of_day).exists?
    end

    def recent_recovery?
      user.interventions.where(ended_at: (now - RECOVERY_WINDOW)..now).exists?
    end

    def in_declared_meal_or_break?
      near_any_time?(profile&.meal_times, 20) || near_any_time?(profile&.protected_breaks, 20)
    end

    def near_any_time?(times, minutes)
      Array(times).any? { |time| near_time?(time, minutes) }
    end

    def near_time?(time, minutes)
      return false if time.blank?

      target = Time.zone.parse(time.to_s)
      return false unless target

      current_minutes = now.hour * 60 + now.min
      target_minutes = target.hour * 60 + target.min
      (current_minutes - target_minutes).abs <= minutes
    rescue ArgumentError
      false
    end

    def routine_active?
      return false unless profile

      start_minutes = minutes_from_string(profile.first_check_in_time)
      end_minutes = minutes_from_string(profile.last_check_in_time)
      current_minutes = now.hour * 60 + now.min
      return false unless start_minutes && end_minutes

      if start_minutes <= end_minutes
        current_minutes.between?(start_minutes, end_minutes)
      else
        current_minutes >= start_minutes || current_minutes <= end_minutes
      end
    end

    def minutes_from_string(value)
      parsed = Time.zone.parse(value.to_s)
      parsed.hour * 60 + parsed.min
    rescue ArgumentError, NoMethodError
      nil
    end
  end
end
