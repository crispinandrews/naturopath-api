module Api
  module V1
    module Client
      class PasswordController < BaseController
        include ClientAuthResponses

        def update
          unless @current_client.authenticate(params.require(:current_password))
            return render_error(
              code: "invalid_current_password",
              message: "Invalid current password",
              status: :unauthorized
            )
          end

          @current_client.update!(password: params.require(:new_password))
          @current_client.refresh_tokens.active.find_each(&:revoke!)
          AppEventLogger.info("auth.client_password_changed", **request_context(client_id: @current_client.id))

          render_auth_success(@current_client)
        rescue ActiveRecord::RecordInvalid => e
          render_validation_errors(e.record)
        end
      end
    end
  end
end
