module Tasks
  class SoftDelete
    def initialize(task)
      @task = task
    end

    def call
      @task.update!(
        title: "Tarefa excluida",
        context: nil,
        micro_step_id: nil,
        deleted_at: Time.current
      )
      @task
    end
  end
end
