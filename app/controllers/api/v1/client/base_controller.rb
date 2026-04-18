module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        include TimestampFilterable

        before_action :authenticate_client!

        private

        def serializer_context
          :client
        end
      end
    end
  end
end
