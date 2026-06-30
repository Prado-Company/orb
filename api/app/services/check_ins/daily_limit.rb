module CheckIns
  class DailyLimit
    LIMITS_BY_PLAN = {
      "free" => 2,
      "pro" => 5,
      "teams" => 5
    }.freeze

    Exceeded = Class.new(StandardError)

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def limit
      LIMITS_BY_PLAN.fetch(user.plan, LIMITS_BY_PLAN.fetch("free"))
    end

    def used_count
      user.check_ins.where(created_at: local_day_range).count
    end

    def response_count
      user.check_ins.where(answered_at: local_day_range).count
    end

    def remaining
      [limit - used_count, 0].max
    end

    def can_create?
      used_count < limit
    end

    def can_answer?(check_in)
      check_in.answered? || response_count < limit
    end

    def assert_can_create!
      raise Exceeded, "daily_check_in_limit_reached" unless can_create?
    end

    def assert_can_answer!(check_in)
      raise Exceeded, "daily_check_in_limit_reached" unless can_answer?(check_in)
    end

    def payload
      {
        plan: user.plan,
        limit: limit,
        used: used_count,
        remaining: remaining,
        period: "dia",
        resets_at: local_day_range.end.utc.iso8601,
        enforced_by: "server"
      }
    end

    private

    attr_reader :user, :now

    def local_day_range
      local_now = now.in_time_zone(time_zone)
      local_now.beginning_of_day.utc..local_now.end_of_day.utc
    end

    def time_zone
      ActiveSupport::TimeZone[user.timezone] || Time.zone
    end
  end
end
