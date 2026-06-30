module Api
  module V1
    class HealthController < ApplicationController
      skip_before_action :authenticate_user!

      def show
        render json: {
          status: "ok",
          service: "orb-api",
          version: 1,
          correlation_id: request_correlation_id
        }
      end
    end
  end
end
