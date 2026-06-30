require "rails_helper"

RSpec.describe "API v1 auth", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    it "creates a user session without exposing password or token in JSON" do
      post "/api/v1/auth/sign_up",
           params: {
             user: {
               name: "Ana",
               email: "ana@example.com",
               password: "senha-segura-123",
               timezone: "America/Bahia",
               locale: "pt-BR"
             }
           },
           headers: { "X-Correlation-ID" => "cor_signup_12345", "X-Orb-Source" => "web" }

      expect(response).to have_http_status(:created)
      expect(response.headers["X-Correlation-ID"]).to eq("cor_signup_12345")
      expect(response.headers["Set-Cookie"]).to include("_orb_session=", "HttpOnly", "SameSite=Lax")

      body = parsed_body
      expect(body.dig("user", "email")).to eq("ana@example.com")
      expect(body.dig("session", "authenticated")).to be(true)
      expect(response.body).not_to include("senha-segura-123", "orb_session_")
    end

    it "rejects weak passwords without echoing the submitted password" do
      post "/api/v1/auth/sign_up",
           params: {
             user: {
               name: "Henrique",
               email: "henrique@example.com",
               password: "1234",
               timezone: "America/Bahia",
               locale: "pt-BR"
             }
           },
           headers: { "X-Correlation-ID" => "cor_weak_password_safe", "X-Orb-Source" => "web" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(parsed_body.fetch("error")).to include(
        "code" => "validation_failed",
        "correlation_id" => "cor_weak_password_safe"
      )
      expect(parsed_body.dig("error", "details")).to include(
        { "field" => "password", "issue" => "too_short" },
        { "field" => "password", "issue" => "missing_letter" },
        { "field" => "password", "issue" => "common_password" }
      )
      expect(response.body).not_to include("1234")
    end
  end

  describe "POST /api/v1/auth/login" do
    it "returns a generic auth error without echoing credentials" do
      create_user(email: "ana@example.com", password: "senha-segura-123")

      post "/api/v1/auth/login",
           params: { session: { email: "ana@example.com", password: "errada-token-secreto" } },
           headers: { "X-Correlation-ID" => "cor_login_12345" }

      expect(response).to have_http_status(:unauthorized)
      expect(parsed_body.fetch("error")).to include(
        "code" => "authentication_failed",
        "correlation_id" => "cor_login_12345"
      )
      expect(parsed_body.dig("error", "details")).to eq([])
      expect(response.body).not_to include("errada-token-secreto")
    end
  end

  describe "GET /api/v1/auth/session" do
    it "returns the current authenticated user from an opaque cookie" do
      user = create_user(email: "ana@example.com")
      cookie = issue_cookie_for(user)

      get "/api/v1/auth/session", headers: { "Cookie" => cookie, "X-Correlation-ID" => "cor_session_12345" }

      expect(response).to have_http_status(:ok)
      expect(parsed_body.dig("user", "id")).to eq(user.id.to_s)
      expect(parsed_body.fetch("correlation_id")).to eq("cor_session_12345")
    end

    it "restores the session from the cookie created during sign up" do
      post "/api/v1/auth/sign_up",
           params: {
             user: {
               name: "Ana",
               email: "reload@example.com",
               password: "senha-segura-123",
               timezone: "America/Bahia",
               locale: "pt-BR"
             }
           },
           headers: { "X-Correlation-ID" => "cor_signup_reload_12345", "X-Orb-Source" => "web" }

      cookie = response.headers.fetch("Set-Cookie").split(";").first

      get "/api/v1/auth/session",
          headers: { "Cookie" => cookie, "X-Correlation-ID" => "cor_reload_session_12345" }

      expect(response).to have_http_status(:ok)
      expect(parsed_body.dig("user", "email")).to eq("reload@example.com")
      expect(parsed_body.dig("session", "transport")).to eq("cookie")
      expect(parsed_body.fetch("correlation_id")).to eq("cor_reload_session_12345")
    end
  end

  describe "source validation" do
    it "rejects unknown source values safely" do
      post "/api/v1/auth/sign_up",
           params: { user: { name: "Ana", email: "ana@example.com", password: "senha-segura-123" } },
           headers: { "X-Orb-Source" => "unknown", "X-Correlation-ID" => "cor_source_12345" }

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body.fetch("error")).to include(
        "code" => "invalid_source",
        "correlation_id" => "cor_source_12345"
      )
      expect(parsed_body.dig("error", "details")).to eq([{ "field" => "source", "issue" => "unsupported" }])
    end

    it "rejects operational source spoofing on public endpoints" do
      post "/api/v1/auth/sign_up",
           params: { user: { name: "Ana", email: "spoof@example.com", password: "senha-segura-123" } },
           headers: { "X-Orb-Source" => "admin", "X-Correlation-ID" => "cor_source_admin_spoof" }

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body.fetch("error")).to include(
        "code" => "invalid_source",
        "correlation_id" => "cor_source_admin_spoof"
      )
      expect(User.exists?(email: "spoof@example.com")).to be(false)
    end
  end
end
