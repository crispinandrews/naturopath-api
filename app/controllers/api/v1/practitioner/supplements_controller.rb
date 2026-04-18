module Api
  module V1
    module Practitioner
      class SupplementsController < ResourceIndexesController
        private

        def resource_scope
          @client.supplements
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
