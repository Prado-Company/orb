module CheckIns
  class Respond
    AlreadyAnswered = Class.new(StandardError)
    InvalidResponse = Class.new(StandardError)

    Result = Data.define(:check_in, :energy, :events, :status, :daily_limit)

    def initialize(check_in:, response:, source:, correlation_id:, now: Time.current)
      @check_in = check_in
      @user = check_in.user
      @response = response.to_s
      @source = source
      @correlation_id = correlation_id
      @now = now
    end

    def call
      check_in.with_lock do
        raise AlreadyAnswered, "check_in_already_answered" if check_in.answered?

        daily_limit.assert_can_answer!(check_in)

        return postpone_or_neutralize if postpone_response?

        raise InvalidResponse, "invalid_check_in_response" unless CheckIn::RESPONSE_VALUES.include?(response)

        answer!(response)
      end
    end

    private

    attr_reader :check_in, :user, :response, :source, :correlation_id, :now

    def postpone_or_neutralize
      if check_in.postponements.zero?
        check_in.update!(postponements: 1, source: source)
        event = record_check_in_event(
          "check_in_adiado",
          metadata_minima: {
            adiamentos: check_in.postponements,
            next_prompt_policy: "aguardar",
            punitive: false
          }
        )
        return Result.new(check_in: check_in, energy: nil, events: [event], status: "adiado", daily_limit: daily_limit.payload)
      end

      check_in.update!(postponements: check_in.postponements + 1)
      answer!("neutro", neutralized_from_postpone: true)
    end

    def answer!(answer, neutralized_from_postpone: false)
      check_in.update!(
        response: answer,
        answered_at: now,
        source: source
      )

      check_in_event = record_check_in_event(
        "check_in_respondido",
        metadata_minima: {
          resposta_tipo: "escala",
          adiamentos: check_in.postponements,
          neutralized_from_postpone: neutralized_from_postpone,
          punitive: false
        }
      )
      calibration = EnergyCalibration.new(user: user, source: source, correlation_id: correlation_id, now: now).from_check_in!(check_in)

      Result.new(
        check_in: check_in,
        energy: calibration.energy,
        events: [check_in_event, calibration.event],
        status: "respondido",
        daily_limit: daily_limit.payload
      )
    end

    def postpone_response?
      CheckIn::POSTPONE_RESPONSES.include?(response)
    end

    def daily_limit
      @daily_limit ||= DailyLimit.new(user: user, now: now)
    end

    def record_check_in_event(event_type, metadata_minima:)
      Foundation::EventRecorder.record_event(
        event_type: event_type,
        actor: { type: "usuario", id: user.id.to_s },
        resource: { type: "check_in", id: check_in.id.to_s },
        source: source,
        correlation_id: correlation_id,
        privacy_level: "sensivel",
        metadata_minima: metadata_minima
      )
    end
  end
end
