class ApplicationController < ActionController::API
  ERROR_ENVELOPE_KEYS = %i[code message details correlation_id].freeze
  PUBLIC_SOURCES = %w[web android ios].freeze

  include Pundit::Authorization
  include CorrelationId

  before_action :set_correlation_id
  before_action :set_request_source
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound do
    render_error(code: "not_found", message: "Recurso nao encontrado.", status: :not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |exception|
    render_error(
      code: "validation_failed",
      message: "Nao foi possivel processar os dados enviados.",
      status: :unprocessable_entity,
      details: validation_details(exception.record)
    )
  end

  rescue_from ActionController::ParameterMissing do |exception|
    render_error(
      code: "validation_failed",
      message: "Nao foi possivel processar os dados enviados.",
      status: :bad_request,
      details: [{ field: exception.param.to_s, issue: "required" }]
    )
  end

  rescue_from Teams::SensitiveIndividualAccessBlocked do
    render_error(
      code: "individual_sensitive_data_blocked",
      message: "Dados individuais sensiveis nao ficam disponiveis em contexto organizacional.",
      status: :forbidden
    )
  end

  rescue_from Pundit::NotAuthorizedError do
    render_error(code: "authorization_denied", message: "Acesso negado.", status: :forbidden)
  end

  attr_reader :request_source

  private

  def authenticate_user!
    return if current_user

    render_error(
      code: "authentication_required",
      message: "Entre na sua conta para continuar.",
      status: :unauthorized
    )
  end

  def current_user
    @current_user ||= ApiSession.authenticate(session_token_from_request)
  end

  def set_request_source
    source = request.headers["X-Orb-Source"].presence || "web"
    allowed = PUBLIC_SOURCES

    unless allowed.include?(source)
      render_error(
        code: "invalid_source",
        message: "Origem da requisicao invalida.",
        status: :bad_request,
        details: [{ field: "source", issue: "unsupported" }]
      )
      return
    end

    @request_source = source
    response.set_header("X-Orb-Source", @request_source)
  end

  def render_error(code:, message:, status:, details: {})
    render(
      status: status,
      json: {
        error: {
          code: code,
          message: message,
          details: normalize_error_details(details),
          correlation_id: request_correlation_id
        }
      }
    )
  end

  def session_token_from_request
    authorization = request.headers["Authorization"].to_s
    bearer = authorization.match(/\ABearer\s+(.+)\z/i)&.[](1)
    cookie_token = request.headers["Cookie"].to_s.match(/(?:\A|;\s*)_orb_session=([^;]+)/)&.[](1)
    bearer.presence || request.headers["X-Orb-Session"].presence || cookie_token.presence
  end

  def validation_details(record)
    record.errors.map do |error|
      { field: error.attribute.to_s, issue: error.type.to_s }
    end
  end

  def normalize_error_details(details)
    safe_details =
      case details
      when Array
        details
      when Hash
        details.map { |field, issue| { field: field.to_s, issue: issue.to_s } }
      else
        []
      end

    Foundation::LogSanitizer.redact(safe_details)
  end

  def set_session_cookie(raw_token, expires_at:)
    cookie = [
      "_orb_session=#{raw_token}",
      "Path=/",
      "HttpOnly",
      "SameSite=Lax",
      "Expires=#{expires_at.httpdate}"
    ]
    cookie << "Secure" if Rails.env.production?
    response.set_header("Set-Cookie", cookie.join("; "))
  end

  def clear_session_cookie
    response.set_header("Set-Cookie", "_orb_session=; Path=/; HttpOnly; SameSite=Lax; Expires=Thu, 01 Jan 1970 00:00:00 GMT")
  end
end
