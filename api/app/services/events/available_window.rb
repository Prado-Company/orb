module Events
  class AvailableWindow
    def initialize(user:, from_time:)
      @user = user
      @from_time = from_time
    end

    def minutes_until_next_event
      next_event = @user.events.active.where("starts_at > ?", @from_time).order(:starts_at).first
      return unless next_event

      ((next_event.starts_at - @from_time) / 60).floor
    end
  end
end
