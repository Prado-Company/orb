module OrbAlgorithm
  class TimeWindow
    def initialize(profile:, now:)
      @profile = profile
      @now = now
    end

    def relation
      return :neutral unless profile

      labels = current_labels
      return :peak if intersects?(profile.peak_windows, labels)
      return :low if intersects?(profile.low_energy_windows, labels)

      :neutral
    end

    private

    attr_reader :profile, :now

    def current_labels
      hour = now.hour
      labels =
        case hour
        when 5..8 then %w[manha_cedo]
        when 9..11 then %w[fim_da_manha manha]
        when 12..14 then %w[depois_do_almoco tarde]
        when 15..17 then %w[fim_da_tarde tarde]
        when 18..22 then %w[noite]
        else %w[madrugada]
        end

      labels << "ao_acordar" if near_time?(profile.first_check_in_time, 90)
      labels << "depois_do_almoco" if near_any_time?(profile.meal_times, 90)
      labels
    end

    def intersects?(configured, labels)
      (Array(configured).map(&:to_s) & labels).any?
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
  end
end
