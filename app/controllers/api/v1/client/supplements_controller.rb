module Api
  module V1
    module Client
      class SupplementsController < ResourcesController
        private

        def resource_scope
          @current_client.supplements
        end

        def resource_params
          params.permit(:name, :dosage, :taken_at, :notes)
        end

        def serializer_class
          SupplementSerializer
        end

        def timestamp_column
          :taken_at
        end
      end
    end
  end
end
