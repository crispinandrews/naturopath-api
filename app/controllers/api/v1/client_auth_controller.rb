module Api
  module V1
    class ClientAuthController < BaseController
      include RateLimitable
      include ClientAuthResponses

      before_action only: :login do
        throttle!(bucket: "client-login", limit: 10, period: 10.minutes, scope: normalized_email_param)
      end

      before_action only: :accept_invite do
        throttle!(bucket: "client-invite-accept", limit: 5, period: 10.minutes, scope: params[:invite_token].to_s.strip)
      end

      before_action only: :forgot_password do
        throttle!(bucket: "client-forgot-password", limit: 5, period: 10.minutes, scope: normalized_email_param)
      end

      before_action only: :reset_password do
        throttle!(bucket: "client-reset-password", limit: 5, period: 10.minutes, scope: params[:reset_token].to_s.strip)
      end

      def login
        client = ::Client.find_by(email: params[:email])

        if client&.invite_accepted_at? && client&.authenticate(params[:password])
          render_auth_success(client)
        else
          AppEventLogger.warn("auth.client_login_failed", **request_context(email: normalized_email_param))
          render_error(code: "invalid_credentials", message: "Invalid email or password", status: :unauthorized)
        end
      end

      def accept_invite
        invite_token = params[:invite_token].to_s.strip
        return render_invalid_invite unless invite_token.present?

        client = ::Client.where(invite_accepted_at: nil).find_by(invite_token: invite_token)
        return render_invalid_invite if client.nil?
        return render_expired_invite(client) if client.invite_expired?

        client.accept_invite!(password: params[:password])
        AppEventLogger.info("auth.client_invite_accepted", **request_context(client_id: client.id))
        render_auth_success(client)
      rescue ::Client::ExpiredInviteError
        render_expired_invite(client)
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      def forgot_password
        client = ::Client.find_by(email: normalized_email_param)

        if client&.invite_accepted_at?
          issued_token = ::PasswordResetToken.issue_for!(client)
          ClientMailer.with(client: client, reset_token: issued_token[:plaintext_token]).password_reset.deliver_later
          AppEventLogger.info("auth.client_password_reset_requested", **request_context(client_id: client.id))
        end

        head :no_content
      end

      def reset_password
        password_reset_token = ::PasswordResetToken.find_by_plaintext(params.require(:reset_token))
        return render_invalid_reset_token if password_reset_token.nil?

        client = password_reset_token.reset_password!(password: params.require(:password))
        AppEventLogger.info("auth.client_password_reset_completed", **request_context(client_id: client.id))
        render_auth_success(client)
      rescue ActionController::ParameterMissing => e
        raise e
      rescue ::PasswordResetToken::InvalidTokenError
        AppEventLogger.warn("auth.client_password_reset_rejected", **request_context)
        render_invalid_reset_token
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      def refresh
        refresh_token = ::RefreshToken.find_by_plaintext(params.require(:refresh_token))
        return render_invalid_refresh_token if refresh_token.nil?

        rotation = refresh_token.rotate!
        render_auth_success(rotation[:record].client, refresh_token: rotation[:plaintext_token])
      rescue ActionController::ParameterMissing => e
        raise e
      rescue ::RefreshToken::InvalidTokenError
        AppEventLogger.warn("auth.client_refresh_token_rejected", **request_context)
        render_invalid_refresh_token
      end

      def logout
        refresh_token = ::RefreshToken.find_by_plaintext(params.require(:refresh_token))
        refresh_token&.revoke!

        head :no_content
      end

      private

      def render_invalid_invite
        render_error(code: "invite_not_found", message: "Invalid invite", status: :not_found)
      end

      def render_expired_invite(client)
        AppEventLogger.warn("auth.client_invite_expired", **request_context(client_id: client.id))
        render_error(code: "invite_expired", message: "Invite has expired", status: :gone)
      end

      def render_invalid_refresh_token
        render_error(
          code: "invalid_refresh_token",
          message: "Invalid refresh token",
          status: :unauthorized
        )
      end

      def render_invalid_reset_token
        render_error(
          code: "invalid_reset_token",
          message: "Invalid reset token",
          status: :unauthorized
        )
      end
    end
  end
end
