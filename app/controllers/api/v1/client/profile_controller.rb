module Api
  module V1
    module Client
      class ProfileController < BaseController
        def show
          render json: {
            id: @current_client.id,
            email: @current_client.email,
            first_name: @current_client.first_name,
            last_name: @current_client.last_name,
            date_of_birth: @current_client.date_of_birth,
            practitioner: {
              first_name: @current_client.practitioner.first_name,
              last_name: @current_client.practitioner.last_name,
              practice_name: @current_client.practitioner.practice_name
            }
          }
        end
      end
    end
  end
end
