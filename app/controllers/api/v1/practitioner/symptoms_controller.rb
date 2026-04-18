module Api
  module V1
    module Practitioner
      class SymptomsController < ResourceIndexesController
        private

        def resource_scope
          @client.symptoms
        end

        def serializer_class
          SymptomSerializer
        end

        def timestamp_column
          :occurred_at
        end
      end
    end
  end
end
