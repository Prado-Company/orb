module Api
  module V1
    class InterventionsController < BaseController
      def index
        interventions = policy_scope(Intervention).order(started_at: :desc).limit(20)

        render json: {
          version: 1,
          interventions: interventions.map { |intervention| serialize_intervention(intervention) },
          correlation_id: request_correlation_id,
          privacy_level: "sensivel"
        }
      end

      def create
        intervention = current_user.interventions.build(intervention_attributes)
        authorize intervention
        intervention.save!
        event = record_event(
          "intervencao_iniciada",
          intervention,
          metadata_minima: {
            tipo: intervention.intervention_type,
            duracao_prevista_minutos: intervention.estimated_minutes,
            gatilho: intervention.trigger,
            punitive: false
          }.compact
        )

        render status: :created, json: {
          version: 1,
          intervention: serialize_intervention(intervention),
          events: [event],
          correlation_id: request_correlation_id,
          privacy_level: "sensivel"
        }
      end

      def update
        intervention = policy_scope(Intervention).find(params[:id])
        authorize intervention

        result = ::Interventions::Finish.new(
          intervention: intervention,
          feedback: intervention_update_params[:feedback],
          source: request_source,
          correlation_id: request_correlation_id
        ).call

        render json: {
          version: 1,
          intervention: serialize_intervention(result.intervention),
          energy: serialize_energy(result.energy),
          events: result.events,
          correlation_id: request_correlation_id,
          privacy_level: "sensivel"
        }
      rescue ::Interventions::Finish::AlreadyFinished
        render_error(
          code: "intervention_already_finished",
          message: "Esta intervencao ja foi finalizada.",
          status: :conflict
        )
      end

      private

      def intervention_attributes
        payload = params[:intervention].present? ? params.require(:intervention) : params
        permitted = payload.permit(
          :tipo, :intervention_type,
          :gatilho, :trigger,
          :duracao_prevista_minutos, :estimated_minutes,
          :inicio, :started_at
        )

        {
          intervention_type: permitted[:intervention_type] || permitted[:tipo] || "respiracao_guiada",
          trigger: permitted[:trigger] || permitted[:gatilho],
          estimated_minutes: permitted[:estimated_minutes] || permitted[:duracao_prevista_minutos] || 3,
          started_at: permitted[:started_at] || permitted[:inicio] || Time.current,
          source: request_source
        }
      end

      def intervention_update_params
        payload = params[:intervention].present? ? params.require(:intervention) : params
        payload.permit(:feedback)
      end

      def serialize_intervention(intervention)
        {
          version: 1,
          id: intervention.id.to_s,
          usuario_id: intervention.user_id.to_s,
          tipo: intervention.intervention_type,
          gatilho: intervention.trigger,
          duracao_prevista_minutos: intervention.estimated_minutes,
          inicio: intervention.started_at.utc.iso8601,
          fim: intervention.ended_at&.utc&.iso8601,
          efeito_estimado: intervention.estimated_effect,
          feedback: intervention.feedback,
          source: intervention.source,
          privacy_level: "sensivel"
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

      def record_event(event_type, intervention, metadata_minima:)
        Foundation::EventRecorder.record_event(
          event_type: event_type,
          actor: { type: "usuario", id: current_user.id.to_s },
          resource: { type: "intervencao", id: intervention.id.to_s },
          source: request_source,
          correlation_id: request_correlation_id,
          privacy_level: "sensivel",
          metadata_minima: metadata_minima
        )
      end
    end
  end
end
