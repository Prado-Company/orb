require "rails_helper"

RSpec.describe "API v1 tasks sprint 4", type: :request do
  it "requires authentication before listing tasks" do
    get "/api/v1/tasks", headers: { "X-Correlation-ID" => "cor_tasks_auth_required" }

    expect(response).to have_http_status(:unauthorized)
    expect(parsed_body.dig("error", "code")).to eq("authentication_required")
  end

  it "creates, partially updates, completes and postpones a task owned by the authenticated user" do
    user = create_user(email: "task-owner@example.com", name: "Task Owner")

    post "/api/v1/tasks",
         params: {
           task: {
             titulo: "Produzir relatorio",
             categoria: "trabalho",
             prazo: "2026-06-20",
             duracao_estimada_minutos: 45,
             peso: "medio",
             contexto: "Relatorio mensal para revisao"
           }
         },
         headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_create" }

    expect(response).to have_http_status(:created)
    task = Task.find(parsed_body.dig("task", "id"))
    expect(task.user_id).to eq(user.id)
    expect(parsed_body.dig("task", "origem")).to eq("usuario")

    patch "/api/v1/tasks/#{task.id}",
          params: { changes: { titulo: "Produzir relatorio revisado" } },
          headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_partial_update" }

    expect(response).to have_http_status(:ok)
    expect(task.reload.title).to eq("Produzir relatorio revisado")
    expect(task.category).to eq("trabalho")
    expect(task.estimated_minutes).to eq(45)
    expect(DomainEvent.where(event_type: "tarefa_atualizada", correlation_id: "cor_task_partial_update")).to exist

    patch "/api/v1/tasks/#{task.id}",
          params: { changes: { status: "concluido" } },
          headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_done" }

    expect(response).to have_http_status(:ok)
    expect(DomainEvent.where(event_type: "tarefa_atualizada", correlation_id: "cor_task_done")).to exist
    expect(DomainEvent.where(event_type: "tarefa_concluida", correlation_id: "cor_task_done")).to exist

    patch "/api/v1/tasks/#{task.id}",
          params: { changes: { status: "adiado" } },
          headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_postponed" }

    expect(response).to have_http_status(:ok)
    expect(DomainEvent.where(event_type: "tarefa_adiada", correlation_id: "cor_task_postponed")).to exist
  end

  it "soft deletes with a minimized tombstone and hides the task from active views" do
    user = create_user(email: "delete-task@example.com", name: "Delete Task")
    task = user.tasks.create!(
      title: "Tarefa com contexto privado",
      category: "trabalho",
      context: "Conteudo livre que nao deve ir para tombstone",
      status: "nao_iniciado",
      origin: "user"
    )

    delete "/api/v1/tasks/#{task.id}",
           headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_delete" }

    expect(response).to have_http_status(:no_content)
    expect(task.reload.deleted_at).to be_present

    get "/api/v1/tasks", headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_list_after_delete" }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("tasks")).to eq([])

    tombstone = DomainEvent.find_by!(event_type: "tarefa_excluida", correlation_id: "cor_task_delete")
    expect(tombstone.metadata_minima.to_s).not_to include("Tarefa com contexto privado", "Conteudo livre")

    get "/api/v1/tasks/#{task.id}", headers: { "Cookie" => issue_cookie_for(user), "X-Correlation-ID" => "cor_task_show_deleted" }

    expect(response).to have_http_status(:not_found)
  end

  it "does not let another user update or delete a task" do
    owner = create_user(email: "owner@example.com", name: "Owner")
    other = create_user(email: "other@example.com", name: "Other")
    task = owner.tasks.create!(title: "Privada", status: "nao_iniciado", origin: "user")

    patch "/api/v1/tasks/#{task.id}",
          params: { changes: { titulo: "Tentativa" } },
          headers: { "Cookie" => issue_cookie_for(other), "X-Correlation-ID" => "cor_task_cross_update" }

    expect(response).to have_http_status(:not_found)
    expect(task.reload.title).to eq("Privada")

    delete "/api/v1/tasks/#{task.id}",
           headers: { "Cookie" => issue_cookie_for(other), "X-Correlation-ID" => "cor_task_cross_delete" }

    expect(response).to have_http_status(:not_found)
    expect(task.reload.deleted_at).to be_nil
  end
end
