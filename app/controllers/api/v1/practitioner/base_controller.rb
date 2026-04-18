module Api
  module V1
    module Practitioner
      class BaseController < Api::V1::BaseController
        include TimestampFilterable

        before_action :authenticate_practitioner!
        before_action :set_client

        private

        def set_client
          @client = @current_practitioner.clients.find_by(id: params[:client_id])
          render_not_found unless @client
        end
      end
    end
  end
end
