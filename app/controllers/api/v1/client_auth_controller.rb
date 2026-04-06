module Api
  module V1
    class ClientAuthController < BaseController
      include RateLimitable

      before_action only: :login do
        throttle!(bucket: "client-login", limit: 10, period: 10.minutes, scope: normalized_email_param)
      end

      before_action only: :accept_invite do
        throttle!(bucket: "client-invite-accept", limit: 5, period: 10.minutes, scope: params[:invite_token].to_s.strip)
      end

      def login
        client = ::Client.find_by(email: params[:email])

        if client&.invite_accepted_at? && client&.authenticate(params[:password])
          token = JwtService.encode({ user_id: client.id, user_type: "Client" })
          render json: {
            token: token,
            client: ClientSerializer.as_json(client)
          }
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
        token = JwtService.encode({ user_id: client.id, user_type: "Client" })
        render json: {
          token: token,
          client: ClientSerializer.as_json(client)
        }
      rescue ::Client::ExpiredInviteError
        render_expired_invite(client)
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      private

      def render_invalid_invite
        render_error(code: "invite_not_found", message: "Invalid invite", status: :not_found)
      end

      def render_expired_invite(client)
        AppEventLogger.warn("auth.client_invite_expired", **request_context(client_id: client.id))
        render_error(code: "invite_expired", message: "Invite has expired", status: :gone)
      end
    end
  end
end
