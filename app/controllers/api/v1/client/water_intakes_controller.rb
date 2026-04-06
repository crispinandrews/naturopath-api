module Api
  module V1
    module Client
      class WaterIntakesController < BaseController
        before_action :set_water_intake, only: [:show, :update, :destroy]

        def index
          intakes = filter_by_date_range(@current_client.water_intakes).order(recorded_at: :desc)
          render json: intakes
        end

        def show
          render json: @water_intake
        end

        def create
          intake = @current_client.water_intakes.new(water_intake_params)

          if intake.save
            render json: intake, status: :created
          else
            render_validation_errors(intake)
          end
        end

        def update
          if @water_intake.update(water_intake_params)
            render json: @water_intake
          else
            render_validation_errors(@water_intake)
          end
        end

        def destroy
          @water_intake.destroy!
          head :no_content
        end

        private

        def set_water_intake
          @water_intake = @current_client.water_intakes.find_by(id: params[:id])
          render_not_found unless @water_intake
        end

        def water_intake_params
          params.permit(:amount_ml, :recorded_at)
        end
      end
    end
  end
end
