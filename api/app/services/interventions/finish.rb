module Interventions
  class Finish
    AlreadyFinished = Class.new(StandardError)

    Result = Data.define(:intervention, :energy, :events)

    def initialize(intervention:, feedback:, source:, correlation_id:, now: Time.current)
      @intervention = intervention
      @user = intervention.user
      @feedback = feedback
      @source = source
      @correlation_id = correlation_id
      @now = now
    end

    def call
      intervention.with_lock do
        raise AlreadyFinished, "intervention_already_finished" if intervention.ended_at.present?

        intervention.update!(
          ended_at: now,
          feedback: normalized_feedback,
          estimated_effect: "recuperacao_leve",
          source: source
        )

        finished_event = record_event("intervencao_finalizada", metadata_minima: { feedback_tipo: feedback.present? ? "opcional" : "ausente" })
        calibration = ::CheckIns::EnergyCalibration.new(user: user, source: source, correlation_id: correlation_id, now: now).from_intervention!(intervention)

        Result.new(intervention: intervention, energy: calibration.energy, events: [finished_event, calibration.event])
      end
    end

    private

    attr_reader :intervention, :user, :feedback, :source, :correlation_id, :now

    def normalized_feedback
      return if feedback.blank?
      return feedback if feedback.in?(Intervention::FEEDBACK_VALUES)

      "outro"
    end

    def record_event(event_type, metadata_minima:)
      Foundation::EventRecorder.record_event(
        event_type: event_type,
        actor: { type: "usuario", id: user.id.to_s },
        resource: { type: "intervencao", id: intervention.id.to_s },
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel",
        metadata_minima: metadata_minima.merge(
          tipo: intervention.intervention_type,
          duracao_prevista_minutos: intervention.estimated_minutes,
          punitive: false
        )
      )
    end
  end
end
