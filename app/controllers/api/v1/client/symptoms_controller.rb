module Api
  module V1
    module Client
      class SymptomsController < BaseController
        before_action :set_symptom, only: [:show, :update, :destroy]

        def index
          symptoms = filter_by_date_range(@current_client.symptoms).order(occurred_at: :desc)
          render json: symptoms
        end

        def show
          render json: @symptom
        end

        def create
          symptom = @current_client.symptoms.new(symptom_params)

          if symptom.save
            render json: symptom, status: :created
          else
            render_validation_errors(symptom)
          end
        end

        def update
          if @symptom.update(symptom_params)
            render json: @symptom
          else
            render_validation_errors(@symptom)
          end
        end

        def destroy
          @symptom.destroy!
          head :no_content
        end

        private

        def set_symptom
          @symptom = @current_client.symptoms.find_by(id: params[:id])
          render_not_found unless @symptom
        end

        def symptom_params
          params.permit(:name, :severity, :occurred_at, :duration_minutes, :notes)
        end
      end
    end
  end
end
