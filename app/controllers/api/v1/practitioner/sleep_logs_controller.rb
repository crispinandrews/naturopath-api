module Api
  module V1
    module Practitioner
      class SleepLogsController < BaseController
        def index
          logs = filter_by_date_range(@client.sleep_logs).order(bedtime: :desc)
          render json: logs
        end
      end
    end
  end
end
