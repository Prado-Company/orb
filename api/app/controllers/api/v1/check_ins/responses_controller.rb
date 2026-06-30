module Api
  module V1
    module CheckIns
      class ResponsesController < BaseController
        def create
          check_in = policy_scope(CheckIn).find(params[:check_in_id])
          authorize check_in, :update?

          result = ::CheckIns::Respond.new(
            check_in: check_in,
            response: response_value,
            source: request_source,
            correlation_id: request_correlation_id
          ).call

          render status: result.energy ? :created : :ok, json: response_payload(result)
        rescue ::CheckIns::DailyLimit::Exceeded
          render_error(
            code: "daily_check_in_limit_reached",
            message: "Seu limite diario de respostas de check-in foi atingido neste plano.",
            status: :too_many_requests,
            details: [{ field: "check_ins", issue: "server_side_daily_limit" }]
          )
        rescue ::CheckIns::Respond::AlreadyAnswered
          render_error(
            code: "check_in_already_answered",
            message: "Este check-in ja foi respondido.",
            status: :conflict
          )
        rescue ::CheckIns::Respond::InvalidResponse, KeyError
          render_error(
            code: "invalid_check_in_response",
            message: "Resposta de check-in invalida.",
            status: :unprocessable_entity,
            details: [{ field: "resposta", issue: "inclusion" }]
          )
        end

        private

        def response_value
          payload =
            if params[:response].present?
              params.require(:response)
            elsif params[:check_in_response].present?
              params.require(:check_in_response)
            else
              params
            end

          permitted = payload.permit(:resposta, :response, :acao, :action)
          permitted[:resposta] || permitted[:response] || permitted[:acao] || permitted[:action]
        end

        def response_payload(result)
          {
            version: 1,
            status: result.status,
            check_in: serialize_check_in(result.check_in),
            energy: result.energy && serialize_energy(result.energy),
            events: result.events,
            daily_limit: result.daily_limit,
            correlation_id: request_correlation_id,
            privacy_level: "sensivel"
          }
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

        def serialize_energy(energy)
          {
            version: 1,
            id: energy.id.to_s,
            usuario_id: energy.user_id.to_s,
            valor: energy.value,
            estado_qualitativo: energy.qualitative_state,
            fonte_calibracao: energy.calibration_source,
            confianca: energy.confidence,
            timestamp: energy.measured_at.utc.iso8601,
            fatores: energy.factors,
            reason_codes: energy.factors,
            source: energy.source,
            privacy_level: "sensivel"
          }
        end
      end
    end
  end
end
