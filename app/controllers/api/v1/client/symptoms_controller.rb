module Api
  module V1
    module Client
      class SymptomsController < ResourcesController
        private

        def resource_scope
          @current_client.symptoms
        end

        def resource_params
          params.permit(:name, :severity, :occurred_at, :duration_minutes, :notes)
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
