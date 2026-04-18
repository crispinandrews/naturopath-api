module Api
  module V1
    module Practitioner
      class EnergyLogsController < ResourceIndexesController
        private

        def resource_scope
          @client.energy_logs
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
