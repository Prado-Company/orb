module Api
  module V1
    class SuggestionsController < BaseController
      ACTION_EVENT_TYPES = {
        "comecar" => "sugestao_aceita",
        "adiar" => "sugestao_adiada",
        "trocar" => "sugestao_trocada"
      }.freeze

      def next_action
        result = ::Suggestions::NextAction.new(
          user: current_user,
          source: request_source,
          correlation_id: request_correlation_id
        ).call

        authorize result.suggestion
        render json: result.payload
      end

      def actions
        suggestion = policy_scope(Suggestion).find(params[:id])
        authorize suggestion, :update?

        action = action_value
        unless ACTION_EVENT_TYPES.key?(action)
          render_error(
            code: "invalid_suggestion_action",
            message: "Acao de sugestao invalida.",
            status: :unprocessable_entity,
            details: [{ field: "action", issue: "inclusion" }]
          )
          return
        end

        event = nil
        suggestion.with_lock do
          suggestion.update!(action_taken: action)
          event = Foundation::EventRecorder.record_event(
            event_type: ACTION_EVENT_TYPES.fetch(action),
            actor: { type: "usuario", id: current_user.id.to_s },
            resource: { type: "sugestao", id: suggestion.id.to_s },
            source: request_source,
            correlation_id: request_correlation_id,
            privacy_level: "sensivel",
            metadata_minima: {
              action: action,
              suggested_item_type: suggestion.suggested_item_type,
              suggested_item_id: suggestion.suggested_item_id&.to_s,
              llm_used: false,
              punitive: false
            }.compact
          )
        end

        render json: {
          version: 1,
          suggestion_id: suggestion.id.to_s,
          action_taken: suggestion.action_taken,
          event: event,
          correlation_id: request_correlation_id,
          privacy_level: "sensivel"
        }
      end

      private

      def action_value
        payload = params[:suggestion_action].present? ? params.require(:suggestion_action) : params
        permitted = payload.permit(:action, :acao)
        permitted[:action] || permitted[:acao]
      end
    end
  end
end
