module Api
  module V1
    module Practitioner
      class FoodEntriesController < ResourceIndexesController
        private

        def resource_scope
          @client.food_entries
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
