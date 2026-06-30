module Api
  module V1
    class EventsController < BaseController
      def index
        events = policy_scope(Event).active.order(starts_at: :asc)
        from_time = parse_time_param(params[:at]) || Time.current
        available_window_minutes = Events::AvailableWindow.new(user: current_user, from_time: from_time).minutes_until_next_event

        render json: {
          version: 1,
          events: events.map { |event| serialize_event(event) },
          available_window_minutes: available_window_minutes,
          correlation_id: request_correlation_id
        }
      end

      def show
        render json: { version: 1, event: serialize_event(scoped_event), correlation_id: request_correlation_id }
      end

      def create
        event = current_user.events.build(event_attributes)
        authorize event
        event.save!

        record_event("evento_criado", event, metadata_minima: { origem: event.origin, categoria: event.category })
        render status: :created, json: { version: 1, event: serialize_event(event), correlation_id: request_correlation_id }
      end

      def update
        event = scoped_event
        authorize event
        return render_external_write_blocked(event) unless external_write_allowed?(event)

        Events::ApplyUpdate.new(event).call(event_attributes)
        record_event("evento_atualizado", event, metadata_minima: { status: event.status, origem: event.origin })

        render json: { version: 1, event: serialize_event(event), correlation_id: request_correlation_id }
      end

      def destroy
        event = scoped_event
        authorize event
        return render_external_write_blocked(event) unless external_write_allowed?(event)

        Events::SoftDelete.new(event).call
        record_event("evento_excluido", event, metadata_minima: { origem: event.origin })

        head :no_content
      end

      def external_origin
        event = scoped_event
        authorize event

        if ActiveModel::Type::Boolean.new.cast(params[:write_external])
          render_error(
            code: "external_calendar_write_requires_consent",
            message: "Escrita em calendario externo exige consentimento explicito.",
            status: :forbidden
          )
          return
        end

        event.update!(external_origin_attributes)
        record_event("evento_atualizado", event, metadata_minima: { origem: event.origin, read_only: true })
        render json: { version: 1, event: serialize_event(event), correlation_id: request_correlation_id }
      end

      private

      def scoped_event
        policy_scope(Event).active.find(params[:id])
      end

      def event_attributes
        payload = event_payload
        permitted = payload.permit(
          :title, :titulo,
          :starts_at, :inicio,
          :ends_at, :fim,
          :timezone,
          :category, :categoria,
          :weight, :peso,
          :status
        )

        {
          title: permitted[:title] || permitted[:titulo],
          starts_at: permitted[:starts_at] || permitted[:inicio],
          ends_at: permitted[:ends_at] || permitted[:fim],
          timezone: permitted[:timezone],
          category: permitted[:category] || permitted[:categoria],
          weight: permitted[:weight] || permitted[:peso],
          status: permitted[:status]
        }.compact
      end

      def external_origin_attributes
        payload = event_payload
        permitted = payload.permit(:origin, :origem, :external_ref)

        {
          origin: normalize_event_origin(permitted[:origin] || permitted[:origem]),
          external_ref: permitted[:external_ref]
        }.compact
      end

      def event_payload
        if params[:changes].present?
          params.require(:changes)
        elsif params[:event].present?
          params.require(:event)
        else
          params
        end
      end

      def normalize_event_origin(origin)
        return if origin.blank?

        { "usuario" => "user" }.fetch(origin, origin)
      end

      def serialize_event(event)
        {
          version: 1,
          id: event.id.to_s,
          usuario_id: event.user_id.to_s,
          organizacao_id: event.organization_id&.to_s,
          titulo: event.title,
          inicio: event.starts_at.utc.iso8601,
          fim: event.ends_at.utc.iso8601,
          timezone: event.timezone,
          categoria: event.category,
          peso: event.weight,
          status: event.status,
          recorrencia: event.recurrence.presence,
          origem: serialize_event_origin(event.origin),
          external_ref: event.external_ref,
          privacy_level: event.privacy_level,
          created_at: event.created_at.utc.iso8601,
          updated_at: event.updated_at.utc.iso8601
        }
      end

      def serialize_event_origin(origin)
        { "user" => "usuario" }.fetch(origin, origin)
      end

      def external_write_allowed?(event)
        consent = ActiveModel::Type::Boolean.new.cast(
          params[:external_calendar_write_consent] || params[:consentimento_escrita_externa]
        )
        Events::ExternalWritePolicy.new(event: event, consent: consent).allowed?
      end

      def render_external_write_blocked(event)
        record_event(
          "evento_escrita_externa_bloqueada",
          event,
          metadata_minima: { origem: event.origin, external_ref_present: event.external_ref.present? }
        )
        render_error(
          code: Events::ExternalWritePolicy::ERROR_CODE,
          message: "Escrita em calendario externo exige consentimento explicito.",
          status: :forbidden
        )
      end

      def parse_time_param(value)
        return if value.blank?

        Time.iso8601(value)
      rescue ArgumentError
        nil
      end

      def record_event(event_type, event, metadata_minima:)
        Foundation::EventRecorder.record_event(
          event_type: event_type,
          actor: { type: "usuario", id: current_user.id.to_s },
          resource: { type: "evento", id: event.id.to_s },
          source: request_source,
          correlation_id: request_correlation_id,
          privacy_level: event.privacy_level,
          metadata_minima: metadata_minima
        )
      end
    end
  end
end
