module Api
  module V1
    module Client
      class WaterIntakesController < ResourcesController
        private

        def resource_scope
          @current_client.water_intakes
        end

        def resource_params
          params.permit(:amount_ml, :recorded_at)
        end

        def serializer_class
          WaterIntakeSerializer
        end

        def timestamp_column
          :recorded_at
        end
      end
    end
  end
end
