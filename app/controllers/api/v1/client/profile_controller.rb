module Api
  module V1
    module Client
      class ProfileController < BaseController
        def show
          render_resource(@current_client, serializer: ClientProfileSerializer)
        end

        def update
          if @current_client.update(profile_params)
            render_resource(@current_client, serializer: ClientProfileSerializer)
          else
            render_validation_errors(@current_client)
          end
        end

        private

        def profile_params
          params.permit(:email, :first_name, :last_name, :date_of_birth)
        end
      end
    end
  end
end
