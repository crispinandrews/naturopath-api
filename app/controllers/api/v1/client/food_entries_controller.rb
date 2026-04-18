module Api
  module V1
    module Client
      class FoodEntriesController < ResourcesController
        private

        def resource_scope
          @current_client.food_entries
        end

        def resource_params
          params.permit(:meal_type, :description, :consumed_at, :notes)
        end

        def serializer_class
          FoodEntrySerializer
        end

        def timestamp_column
          :consumed_at
        end
      end
    end
  end
end
