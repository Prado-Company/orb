module History
  class Timeline
    FREE_HISTORY_DAYS = 14
    RESOURCE_TYPES = %w[tarefa evento check_in energia intervencao].freeze
    DOWNGRADE_BEHAVIOR = "downgrade_preserva_dados_e_oculta_historico_fora_do_plano".freeze

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def entries
      (domain_event_entries + energy_entries + check_in_entries + intervention_entries)
        .sort_by { |entry| Time.iso8601(entry.fetch(:occurred_at)) }
        .reverse
        .first(100)
    end

    def entitlement
      {
        plan: @user.plan,
        history_window_days: free_plan? ? FREE_HISTORY_DAYS : nil,
        full_history: !free_plan?,
        downgrade_behavior: DOWNGRADE_BEHAVIOR
      }
    end

    private

    def domain_event_entries
      scope = DomainEvent
        .where(actor_type: "usuario", actor_id: @user.id.to_s)
        .where(resource_type: RESOURCE_TYPES)
      scope = apply_window(scope, :occurred_at)

      scope.order(occurred_at: :desc).map do |event|
        {
          version: 1,
          kind: event.resource_type,
          event_type: event.event_type,
          occurred_at: event.occurred_at.utc.iso8601,
          resource: { type: event.resource_type, id: event.resource_id },
          source: event.source,
          correlation_id: event.correlation_id,
          privacy_level: event.privacy_level,
          summary: resource_summary(event)
        }
      end
    end

    def energy_entries
      scope = apply_window(@user.energies, :measured_at)
      scope.order(measured_at: :desc).map do |energy|
        {
          version: 1,
          kind: "energia",
          event_type: "energia_registrada",
          occurred_at: energy.measured_at.utc.iso8601,
          resource: { type: "energia", id: energy.id.to_s },
          source: energy.source,
          privacy_level: "sensivel",
          summary: {
            estado_qualitativo: energy.qualitative_state,
            valor: energy.value,
            confianca: energy.confidence,
            reason_codes: energy.factors
          }
        }
      end
    end

    def check_in_entries
      scope = apply_window(@user.check_ins, :created_at)
      scope.order(created_at: :desc).map do |check_in|
        {
          version: 1,
          kind: "check_in",
          event_type: check_in.answered_at.present? ? "check_in_respondido" : "check_in_criado",
          occurred_at: (check_in.answered_at || check_in.created_at).utc.iso8601,
          resource: { type: "check_in", id: check_in.id.to_s },
          source: check_in.source,
          privacy_level: "sensivel",
          summary: {
            tipo: check_in.kind,
            resposta_tipo: check_in.response.present? ? "escala" : nil
          }.compact
        }
      end
    end

    def intervention_entries
      scope = apply_window(@user.interventions, :started_at)
      scope.order(started_at: :desc).map do |intervention|
        {
          version: 1,
          kind: "intervencao",
          event_type: intervention.ended_at.present? ? "intervencao_finalizada" : "intervencao_iniciada",
          occurred_at: (intervention.ended_at || intervention.started_at).utc.iso8601,
          resource: { type: "intervencao", id: intervention.id.to_s },
          source: intervention.source,
          privacy_level: "sensivel",
          summary: {
            tipo: intervention.intervention_type,
            duracao_prevista_minutos: intervention.estimated_minutes
          }
        }
      end
    end

    def resource_summary(event)
      return tombstone_summary(event) if event.event_type.end_with?("_excluida", "_excluido")

      case event.resource_type
      when "tarefa"
        task = @user.tasks.active.find_by(id: event.resource_id)
        task ? { titulo: task.title, status: task.status, categoria: task.category }.compact : tombstone_summary(event)
      when "evento"
        calendar_event = @user.events.active.find_by(id: event.resource_id)
        calendar_event ? { titulo: calendar_event.title, status: calendar_event.status, categoria: calendar_event.category }.compact : tombstone_summary(event)
      else
        event.metadata_minima.except("titulo", "contexto", "context")
      end
    end

    def tombstone_summary(event)
      {
        tombstone: true,
        status: event.metadata_minima["status"],
        origem: event.metadata_minima["origem"]
      }.compact
    end

    def apply_window(scope, column)
      return scope unless free_plan?

      scope.where("#{column} >= ?", @now - FREE_HISTORY_DAYS.days)
    end

    def free_plan?
      @user.plan == "free"
    end
  end
end
