module Api
  module V1
    module Client
      class EnergyLogsController < ResourcesController
        private

        def resource_scope
          @current_client.energy_logs
        end

        def resource_params
          params.permit(:level, :recorded_at, :notes)
        end

        def serializer_class
          EnergyLogSerializer
        end

        def timestamp_column
          :recorded_at
        end
      end
    end
  end
end
