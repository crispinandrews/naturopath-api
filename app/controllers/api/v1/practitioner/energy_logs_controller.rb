module Api
  module V1
    module Practitioner
      class EnergyLogsController < BaseController
        def index
          logs = filter_by_date_range(@client.energy_logs, :recorded_at).order(recorded_at: :desc)
          render json: logs
        end
      end
    end
  end
end
