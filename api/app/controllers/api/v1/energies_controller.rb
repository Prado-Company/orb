module Api
  module V1
    class EnergiesController < BaseController
      def current
        Teams::PrivacyGuard.ensure_individual_access!(
          resource_type: "energy",
          org_context: request.headers["X-Orb-Organization-Id"].present?
        )

        energy = policy_scope(Energy).order(measured_at: :desc).first!
        render json: { version: 1, energy: serialize_energy(energy), correlation_id: request_correlation_id }
      end

      private

      def serialize_energy(energy)
        {
          version: 1,
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
