module Api
  module V1
    module Practitioner
      class SleepLogsController < ResourceIndexesController
        private

        def resource_scope
          @client.sleep_logs
        end

        def serializer_class
          SleepLogSerializer
        end

        def timestamp_column
          :bedtime
        end
      end
    end
  end
end
