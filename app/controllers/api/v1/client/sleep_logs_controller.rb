module Api
  module V1
    module Client
      class SleepLogsController < BaseController
        before_action :set_sleep_log, only: [ :show, :update, :destroy ]

        def index
          logs = filter_by_date_range(@current_client.sleep_logs, :bedtime).order(bedtime: :desc)
          render json: logs
        end

        def show
          render json: @sleep_log
        end

        def create
          log = @current_client.sleep_logs.new(sleep_log_params)

          if log.save
            render json: log, status: :created
          else
            render_validation_errors(log)
          end
        end

        def update
          if @sleep_log.update(sleep_log_params)
            render json: @sleep_log
          else
            render_validation_errors(@sleep_log)
          end
        end

        def destroy
          @sleep_log.destroy!
          head :no_content
        end

        private

        def set_sleep_log
          @sleep_log = @current_client.sleep_logs.find_by(id: params[:id])
          render_not_found unless @sleep_log
        end

        def sleep_log_params
          params.permit(:bedtime, :wake_time, :quality, :hours_slept, :notes)
        end
      end
    end
  end
end
