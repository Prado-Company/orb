require "rails_helper"

RSpec.describe "API v1 error contract", type: :request do
  it "uses the standard error envelope for unauthenticated sensitive mutations" do
    post "/api/v1/tasks",
         params: { task: { title: "Segredo", token: "tok_live_123", prompt_completo: "texto livre" } },
         headers: { "X-Correlation-ID" => "cor_error_12345" }

    expect(response).to have_http_status(:unauthorized)
    error = parsed_body.fetch("error")
    expect(error.keys).to contain_exactly("code", "message", "details", "correlation_id")
    expect(error).to include("code" => "authentication_required", "correlation_id" => "cor_error_12345")
    expect(error.fetch("details")).to eq([])
    expect(response.body).not_to include("tok_live_123", "texto livre")
  end
end
