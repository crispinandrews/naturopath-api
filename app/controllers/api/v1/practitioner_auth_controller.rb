module Api
  module V1
    class PractitionerAuthController < BaseController
      include RateLimitable

      before_action only: :login do
        throttle!(bucket: "practitioner-login", limit: 10, period: 10.minutes, scope: normalized_email_param)
      end

      def login
        practitioner = ::Practitioner.find_by(email: params[:email])

        if practitioner&.authenticate(params[:password])
          token = JwtService.encode({ user_id: practitioner.id, user_type: "Practitioner" })
          render json: {
            token: token,
            practitioner: PractitionerSerializer.as_json(practitioner)
          }
        else
          AppEventLogger.warn("auth.practitioner_login_failed", **request_context(email: normalized_email_param))
          render_error(code: "invalid_credentials", message: "Invalid email or password", status: :unauthorized)
        end
      end

      private
    end
  end
end
