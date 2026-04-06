module Api
  module V1
    module Practitioner
      class SupplementsController < BaseController
        def index
          supplements = filter_by_date_range(@client.supplements, :taken_at).order(taken_at: :desc)
          render json: supplements
        end
      end
    end
  end
end
