module Api
  module V1
    class PractitionerAuthController < BaseController
      def login
        practitioner = ::Practitioner.find_by(email: params[:email])

        if practitioner&.authenticate(params[:password])
          token = JwtService.encode({ user_id: practitioner.id, user_type: "Practitioner" })
          render json: {
            token: token,
            practitioner: practitioner_json(practitioner)
          }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def register
        practitioner = ::Practitioner.new(practitioner_params)

        if practitioner.save
          token = JwtService.encode({ user_id: practitioner.id, user_type: "Practitioner" })
          render json: {
            token: token,
            practitioner: practitioner_json(practitioner)
          }, status: :created
        else
          render_validation_errors(practitioner)
        end
      end

      private

      def practitioner_params
        params.permit(:email, :password, :password_confirmation, :first_name, :last_name, :practice_name)
      end

      def practitioner_json(practitioner)
        {
          id: practitioner.id,
          email: practitioner.email,
          first_name: practitioner.first_name,
          last_name: practitioner.last_name,
          practice_name: practitioner.practice_name
        }
      end
    end
  end
end
