module OrbAlgorithm
  class EventCost
    def initialize(profile:, now:)
      @profile = profile
      @now = now
    end

    def drain(event)
      duration = duration_minutes(event)
      value = base_drain(duration)
      value += 8 if long_meeting_trigger?(event, duration)
      value += 6 if displacement?(event)
      value += 5 if glued_to_previous_event?(event)
      value *= 1.20 if window_relation == :low
      value *= 0.90 if window_relation == :peak
      value.round
    end

    private

    attr_reader :profile, :now

    def duration_minutes(event)
      ((event.ends_at - event.starts_at) / 60).ceil
    end

    def base_drain(duration)
      OrbAlgorithm::Config::EVENT_BASE_DRAIN.find { |max, _value| duration <= max }.last
    end

    def long_meeting_trigger?(event, duration)
      duration > 60 && Array(profile&.triggers).map(&:to_s).include?("reunioes_longas") &&
        event.category.to_s.match?(/trabalho|reuniao|reuni/).present?
    end

    def displacement?(event)
      event.category.to_s == "deslocamento" || Array(profile&.triggers).map(&:to_s).include?("deslocamento")
    end

    def glued_to_previous_event?(event)
      event.user.events.active
        .where.not(id: event.id)
        .where(ends_at: (event.starts_at - 15.minutes)..event.starts_at)
        .exists?
    end

    def window_relation
      @window_relation ||= OrbAlgorithm::TimeWindow.new(profile: profile, now: now).relation
    end
  end
end
