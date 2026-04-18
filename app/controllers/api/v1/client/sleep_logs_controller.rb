module Api
  module V1
    module Client
      class SleepLogsController < ResourcesController
        private

        def resource_scope
          @current_client.sleep_logs
        end

        def resource_params
          params.permit(:bedtime, :wake_time, :quality, :hours_slept, :notes)
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
