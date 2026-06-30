require "rails_helper"

RSpec.describe "API v1 task isolation", type: :request do
  it "does not reveal tasks owned by another user" do
    ana = create_user(email: "ana@example.com", name: "Ana")
    bia = create_user(email: "bia@example.com", name: "Bia")
    task = bia.tasks.create!(title: "Tarefa privada", status: "nao_iniciado", origin: "user")

    get "/api/v1/tasks/#{task.id}",
        headers: { "Cookie" => issue_cookie_for(ana), "X-Correlation-ID" => "cor_iso_12345" }

    expect(response).to have_http_status(:not_found)
    expect(parsed_body.dig("error", "code")).to eq("not_found")
    expect(response.body).not_to include("Tarefa privada")
  end

  it "ignores user_id from task payload and binds created tasks to the authenticated user" do
    ana = create_user(email: "ana@example.com", name: "Ana")
    bia = create_user(email: "bia@example.com", name: "Bia")

    post "/api/v1/tasks",
         params: { task: { title: "Produzir relatorio", user_id: bia.id, status: "nao_iniciado", origin: "user" } },
         headers: { "Cookie" => issue_cookie_for(ana), "X-Correlation-ID" => "cor_create_12345" }

    expect(response).to have_http_status(:created)
    task = Task.find(parsed_body.dig("task", "id"))
    expect(task.user_id).to eq(ana.id)
    expect(task.user_id).not_to eq(bia.id)
    expect(DomainEvent.last.envelope).to include(event_type: "tarefa_criada", correlation_id: "cor_create_12345")
  end
end
