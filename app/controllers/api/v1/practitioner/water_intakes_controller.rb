module Api
  module V1
    module Practitioner
      class WaterIntakesController < ResourceIndexesController
        private

        def resource_scope
          @client.water_intakes
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
