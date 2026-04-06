module Api
  module V1
    module Practitioner
      class WaterIntakesController < BaseController
        def index
          intakes = filter_by_date_range(@client.water_intakes).order(recorded_at: :desc)
          render json: intakes
        end
      end
    end
  end
end
