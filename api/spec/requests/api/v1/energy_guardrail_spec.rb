require "rails_helper"

RSpec.describe "API v1 energy guardrails", type: :request do
  it "blocks individual energy reads in organization context" do
    user = create_user(email: "ana@example.com")
    user.energies.create!(
      value: 62,
      qualitative_state: "media",
      calibration_source: "check_in",
      confidence: "media",
      measured_at: Time.current,
      factors: ["historico_recente"],
      source: "web"
    )

    get "/api/v1/energy/current",
        headers: {
          "Cookie" => issue_cookie_for(user),
          "X-Orb-Organization-Id" => "org_123",
          "X-Correlation-ID" => "cor_energy_12345"
        }

    expect(response).to have_http_status(:forbidden)
    expect(parsed_body.dig("error", "code")).to eq("individual_sensitive_data_blocked")
    expect(response.body).not_to include("62", "historico_recente")
  end
end
