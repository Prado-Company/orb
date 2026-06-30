module Tasks
  class ApplyUpdate
    STATUS_EVENT_TYPES = {
      "concluido" => "tarefa_concluida",
      "adiado" => "tarefa_adiada"
    }.freeze

    attr_reader :extra_event_types

    def initialize(task)
      @task = task
      @extra_event_types = []
    end

    def call(changes)
      previous_status = @task.status
      @task.update!(changes)

      @extra_event_types =
        if @task.status != previous_status
          Array(STATUS_EVENT_TYPES[@task.status])
        else
          []
        end

      @task
    end
  end
end
