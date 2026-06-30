module Api
  module V1
    class CheckInsController < BaseController
      def index
        check_ins = policy_scope(CheckIn).order(created_at: :desc).limit(10)
        limit = ::CheckIns::DailyLimit.new(user: current_user)

        render json: {
          version: 1,
          check_ins: check_ins.map { |check_in| serialize_check_in(check_in) },
          daily_limit: limit.payload,
          correlation_id: request_correlation_id,
          privacy_level: "sensivel"
        }
      end

      def create
        limit = ::CheckIns::DailyLimit.new(user: current_user)
        limit.assert_can_create!

        check_in = current_user.check_ins.build(check_in_attributes)
        authorize check_in
        check_in.save!
        record_check_in_event(
          "check_in_criado",
          check_in,
          metadata_minima: { tipo: check_in.kind, origem: check_in.origin }
        )

        render status: :created, json: {
          version: 1,
          check_in: serialize_check_in(check_in),
          daily_limit: ::CheckIns::DailyLimit.new(user: current_user).payload,
          correlation_id: request_correlation_id,
          privacy_level: "sensivel"
        }
      rescue ::CheckIns::DailyLimit::Exceeded
        render_limit_error(limit)
      end

      private

      def check_in_attributes
        payload = params[:check_in].present? ? params.require(:check_in) : params
        permitted = payload.permit(
          :kind, :tipo,
          :question_id, :pergunta_id,
          :scheduled_time, :horario_previsto,
          :timezone,
          :origin, :origem
        )

        {
          kind: permitted[:kind] || permitted[:tipo] || "estado_energia",
          question_id: permitted[:question_id] || permitted[:pergunta_id] || "q_estado_energia_v1",
          scheduled_time: permitted[:scheduled_time] || permitted[:horario_previsto] || Time.current.in_time_zone(current_user.timezone).strftime("%H:%M"),
          timezone: permitted[:timezone] || current_user.timezone,
          origin: normalize_origin(permitted[:origin] || permitted[:origem] || "manual"),
          source: request_source
        }
      end

      def normalize_origin(origin)
        { "usuario" => "manual" }.fetch(origin.to_s, origin.to_s)
      end

      def serialize_check_in(check_in)
        {
          version: 1,
          id: check_in.id.to_s,
          usuario_id: check_in.user_id.to_s,
          tipo: check_in.kind,
          pergunta_id: check_in.question_id,
          resposta: check_in.response,
          horario_previsto: check_in.scheduled_time,
          horario_respondido: check_in.answered_at&.utc&.iso8601,
          timezone: check_in.timezone,
          adiamentos: check_in.postponements,
          origem: check_in.origin,
          source: check_in.source,
          privacy_level: "sensivel",
          created_at: check_in.created_at.utc.iso8601
        }
      end

      def record_check_in_event(event_type, check_in, metadata_minima:)
        Foundation::EventRecorder.record_event(
          event_type: event_type,
          actor: { type: "usuario", id: current_user.id.to_s },
          resource: { type: "check_in", id: check_in.id.to_s },
          source: request_source,
          correlation_id: request_correlation_id,
          privacy_level: "sensivel",
          metadata_minima: metadata_minima
        )
      end

      def render_limit_error(limit)
        render_error(
          code: "daily_check_in_limit_reached",
          message: "Seu limite diario de check-ins foi atingido neste plano.",
          status: :too_many_requests,
          details: [
            { field: "check_ins", issue: "#{limit.payload.fetch(:plan)}_limit_#{limit.limit}" },
            { field: "enforced_by", issue: "server" }
          ]
        )
      end
    end
  end
end
