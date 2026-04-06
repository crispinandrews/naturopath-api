module Api
  module V1
    module Client
      class EnergyLogsController < BaseController
        before_action :set_energy_log, only: [ :show, :update, :destroy ]

        def index
          logs = filter_by_date_range(@current_client.energy_logs, :recorded_at).order(recorded_at: :desc)
          render json: logs
        end

        def show
          render json: @energy_log
        end

        def create
          log = @current_client.energy_logs.new(energy_log_params)

          if log.save
            render json: log, status: :created
          else
            render_validation_errors(log)
          end
        end

        def update
          if @energy_log.update(energy_log_params)
            render json: @energy_log
          else
            render_validation_errors(@energy_log)
          end
        end

        def destroy
          @energy_log.destroy!
          head :no_content
        end

        private

        def set_energy_log
          @energy_log = @current_client.energy_logs.find_by(id: params[:id])
          render_not_found unless @energy_log
        end

        def energy_log_params
          params.permit(:level, :recorded_at, :notes)
        end
      end
    end
  end
end
