module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        include TimestampFilterable

        before_action :authenticate_client!
      end
    end
  end
end
