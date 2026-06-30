module Onboarding
  class PersistProgress
    def initialize(user:, responses:, current_step:, source:, correlation_id:)
      @user = user
      @responses = responses.deep_symbolize_keys
      @current_step = current_step.to_i
      @source = source
      @correlation_id = correlation_id
    end

    def call
      now = Time.current
      user.update!(
        onboarding_state: "em_andamento",
        onboarding_started_at: user.onboarding_started_at || now,
        onboarding_progress: Foundation::LogSanitizer.redact(
          current_step: current_step.clamp(1, 6),
          total_steps: 6,
          flow_variant: "resumido",
          responses: responses.except(:identificacoes_neurodivergentes),
          updated_at: now.utc.iso8601
        )
      )

      Foundation::EventRecorder.record_event(
        event_type: "onboarding_em_andamento",
        actor: { type: "usuario", id: user.id.to_s },
        resource: { type: "usuario", id: user.id.to_s },
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel",
        metadata_minima: {
          flow_variant: "resumido",
          current_step: current_step.clamp(1, 6)
        }
      )

      ResponseSerializer.new(
        user: user,
        profile: user.energetic_profiles.order(created_at: :desc).first,
        energy: user.energies.order(measured_at: :desc).first,
        event: nil,
        source: source,
        correlation_id: correlation_id,
        onboarding_state: user.onboarding_state
      ).status_payload
    end

    private

    attr_reader :user, :responses, :current_step, :source, :correlation_id
  end
end
