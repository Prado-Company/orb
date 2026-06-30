module Api
  module V1
    class OnboardingController < BaseController
      def status
        render json: status_payload
      end

      def progress
        render json: ::Onboarding::PersistProgress.new(
          user: current_user,
          responses: onboarding_params.to_h,
          current_step: params[:current_step] || params.dig(:onboarding, :current_step),
          source: request_source,
          correlation_id: request_correlation_id
        ).call
      end

      def complete
        render status: :created, json: ::Onboarding::CompleteFlow.new(
          user: current_user,
          responses: onboarding_params.to_h,
          source: request_source,
          correlation_id: request_correlation_id
        ).call
      end

      def skip
        render status: :created, json: ::Onboarding::SkipFlow.new(
          user: current_user,
          source: request_source,
          correlation_id: request_correlation_id
        ).call
      end

      private

      def status_payload
        ::Onboarding::ResponseSerializer.new(
          user: current_user,
          profile: current_user.energetic_profiles.order(created_at: :desc).first,
          energy: current_user.energies.order(measured_at: :desc).first,
          event: nil,
          source: request_source,
          correlation_id: request_correlation_id,
          onboarding_state: current_user.onboarding_state
        ).status_payload
      end

      def onboarding_params
        payload =
          if params.dig(:onboarding, :profile_inputs).present?
            params.require(:onboarding).require(:profile_inputs)
          elsif params[:profile_inputs].present?
            params.require(:profile_inputs)
          elsif params.dig(:onboarding, :answers).present?
            params.require(:onboarding).require(:answers)
          elsif params[:answers].present?
            params.require(:answers)
          elsif params[:onboarding].present?
            params.require(:onboarding)
          else
            params
          end
        payload.permit(
          :nome,
          :pronomes,
          :timezone,
          :idioma,
          :objetivo_principal,
          :sensibilidade,
          :tom_preferido,
          :intensidade_notificacao,
          :horario_primeiro_check_in,
          :horario_ultimo_check_in,
          janelas_pico: [],
          janelas_baixa_energia: [],
          gatilhos: [],
          horarios_refeicoes: [],
          pausas_protegidas: [],
          identificacoes_neurodivergentes: []
        )
      end
    end
  end
end
