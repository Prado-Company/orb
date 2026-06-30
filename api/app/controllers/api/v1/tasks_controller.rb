module Api
  module V1
    class TasksController < BaseController
      def index
        tasks = policy_scope(Task).active.order(created_at: :desc)
        render json: { version: 1, tasks: tasks.map { |task| serialize_task(task) }, correlation_id: request_correlation_id }
      end

      def show
        render json: { version: 1, task: serialize_task(scoped_task), correlation_id: request_correlation_id }
      end

      def create
        task = current_user.tasks.build(task_attributes)
        task.responsible_id = current_user.id
        authorize task
        task.save!

        record_task_event("tarefa_criada", task, metadata_minima: { status: task.status, categoria: task.category })
        render status: :created, json: { version: 1, task: serialize_task(task), correlation_id: request_correlation_id }
      end

      def update
        task = scoped_task
        authorize task
        previous_status = task.status
        update = Tasks::ApplyUpdate.new(task)
        update.call(task_attributes)

        record_task_event("tarefa_atualizada", task, metadata_minima: { status_anterior: previous_status, status_novo: task.status })
        update.extra_event_types.each do |event_type|
          record_task_event(event_type, task, metadata_minima: { status_anterior: previous_status, status_novo: task.status })
        end

        render json: { version: 1, task: serialize_task(task), correlation_id: request_correlation_id }
      end

      def destroy
        task = scoped_task
        authorize task
        Tasks::SoftDelete.new(task).call
        record_task_event("tarefa_excluida", task, metadata_minima: { status: task.status })

        head :no_content
      end

      private

      def scoped_task
        policy_scope(Task).active.find(params[:id])
      end

      def task_attributes
        payload = task_payload
        permitted = payload.permit(
          :title, :titulo,
          :category, :categoria,
          :due_on, :prazo,
          :estimated_minutes, :duracao_estimada_minutos,
          :weight, :peso,
          :status,
          :context, :contexto
        )

        {
          title: permitted[:title] || permitted[:titulo],
          category: permitted[:category] || permitted[:categoria],
          due_on: permitted[:due_on] || permitted[:prazo],
          estimated_minutes: permitted[:estimated_minutes] || permitted[:duracao_estimada_minutos],
          weight: permitted[:weight] || permitted[:peso],
          status: permitted[:status],
          context: permitted[:context] || permitted[:contexto]
        }.compact
      end

      def task_payload
        if params[:changes].present?
          params.require(:changes)
        elsif params[:task].present?
          params.require(:task)
        else
          params
        end
      end

      def serialize_task(task)
        {
          version: 1,
          id: task.id.to_s,
          usuario_id: task.user_id.to_s,
          organizacao_id: task.organization_id&.to_s,
          titulo: task.title,
          categoria: task.category,
          prazo: task.due_on&.iso8601,
          duracao_estimada_minutos: task.estimated_minutes,
          peso: task.weight,
          status: task.status,
          origem: serialize_task_origin(task.origin),
          responsavel_id: task.responsible_id&.to_s,
          contexto_resumido: task.context&.truncate(240),
          micro_passo_id: task.micro_step_id,
          privacy_level: task.privacy_level,
          created_at: task.created_at.utc.iso8601,
          updated_at: task.updated_at.utc.iso8601
        }
      end

      def serialize_task_origin(origin)
        { "user" => "usuario" }.fetch(origin, origin)
      end

      def record_task_event(event_type, task, metadata_minima:)
        Foundation::EventRecorder.record_event(
          event_type: event_type,
          actor: { type: "usuario", id: current_user.id.to_s },
          resource: { type: "tarefa", id: task.id.to_s },
          source: request_source,
          correlation_id: request_correlation_id,
          privacy_level: task.privacy_level,
          metadata_minima: metadata_minima
        )
      end
    end
  end
end
