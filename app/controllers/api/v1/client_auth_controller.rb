module Api
  module V1
    class ClientAuthController < BaseController
      def login
        client = ::Client.find_by(email: params[:email])

        if client&.invite_accepted_at? && client&.authenticate(params[:password])
          token = JwtService.encode({ user_id: client.id, user_type: "Client" })
          render json: {
            token: token,
            client: client_json(client)
          }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def accept_invite
        invite_token = params[:invite_token].to_s.strip
        return render_invalid_invite unless invite_token.present?

        client = ::Client.where(invite_accepted_at: nil).find_by(invite_token: invite_token)

        if client.nil?
          return render_invalid_invite
        end

        client.accept_invite!(password: params[:password])
        token = JwtService.encode({ user_id: client.id, user_type: "Client" })
        render json: {
          token: token,
          client: client_json(client)
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def render_invalid_invite
        render json: { error: "Invalid or expired invite" }, status: :not_found
      end

      def client_json(client)
        {
          id: client.id,
          email: client.email,
          first_name: client.first_name,
          last_name: client.last_name,
          practitioner_id: client.practitioner_id
        }
      end
    end
  end
end
