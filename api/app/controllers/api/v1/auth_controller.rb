module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: %i[sign_up login]

      def sign_up
        user = User.new(sign_up_params.except(:password))
        user.password = sign_up_params[:password]
        user.save!

        token, session = user.issue_session!(
          source: request_source,
          correlation_id: request_correlation_id,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        set_session_cookie(token, expires_at: session.expires_at)

        render status: :created, json: session_payload(user, session)
      rescue ArgumentError => exception
        render_error(
          code: "validation_failed",
          message: "Nao foi possivel processar os dados enviados.",
          status: :unprocessable_entity,
          details: password_error_details(exception)
        )
      end

      def login
        user = User.authenticate(email: login_params[:email], password: login_params[:password])

        unless user
          render_error(
            code: "authentication_failed",
            message: "Email ou senha invalidos.",
            status: :unauthorized
          )
          return
        end

        token, session = user.issue_session!(
          source: request_source,
          correlation_id: request_correlation_id,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        set_session_cookie(token, expires_at: session.expires_at)

        render json: session_payload(user, session)
      end

      def session
        render json: session_payload(current_user, current_api_session)
      end

      def logout
        current_api_session&.revoke!
        clear_session_cookie
        head :no_content
      end

      private

      def sign_up_params
        params.require(:user).permit(:name, :email, :password, :pronouns, :timezone, :locale)
      end

      def login_params
        params.require(:session).permit(:email, :password)
      end

      def password_error_details(exception)
        if exception.message == "password_too_weak"
          User.password_strength_issues(sign_up_params[:password]).map do |issue|
            { field: "password", issue: issue }
          end
        else
          [{ field: "password", issue: "required" }]
        end
      end

      def current_api_session
        @current_api_session ||= ApiSession.active.find_by(token_digest: ApiSession.digest_token(session_token_from_request))
      end

      def session_payload(user, session)
        {
          version: 1,
          user: serialize_user(user),
          session: {
            authenticated: true,
            transport: "cookie",
            expires_at: session.expires_at.utc.iso8601,
            source: session.source
          },
          correlation_id: request_correlation_id,
          privacy_level: "interno"
        }
      end

      def serialize_user(user)
        {
          version: 1,
          id: user.id.to_s,
          nome: user.name,
          email: user.email,
          pronomes: user.pronouns,
          timezone: user.timezone,
          idioma: user.locale,
          plano_atual: user.plan,
          status_conta: contract_account_status(user.account_status),
          onboarding: {
            state: user.onboarding_state,
            current_step: user.onboarding_progress["current_step"],
            total_steps: user.onboarding_progress["total_steps"],
            resume_available: %w[em_andamento pulado revisao_solicitada].include?(user.onboarding_state)
          },
          privacy_level: "interno",
          created_at: user.created_at.utc.iso8601,
          updated_at: user.updated_at.utc.iso8601
        }
      end

      def contract_account_status(status)
        {
          "active" => "ativa",
          "suspended" => "suspensa",
          "soft_deleted" => "soft_delete_aplicado",
          "deleted" => "deletada"
        }.fetch(status, status)
      end
    end
  end
end
