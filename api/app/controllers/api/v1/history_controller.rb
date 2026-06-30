module Api
  module V1
    class HistoryController < BaseController
      def index
        timeline = History::Timeline.new(user: current_user)

        render json: {
          version: 1,
          history: timeline.entries,
          entitlement: timeline.entitlement,
          correlation_id: request_correlation_id,
          privacy_level: "interno"
        }
      end
    end
  end
end
