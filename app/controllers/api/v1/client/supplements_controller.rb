module Api
  module V1
    module Client
      class SupplementsController < BaseController
        before_action :set_supplement, only: [:show, :update, :destroy]

        def index
          supplements = filter_by_date_range(@current_client.supplements).order(taken_at: :desc)
          render json: supplements
        end

        def show
          render json: @supplement
        end

        def create
          supplement = @current_client.supplements.new(supplement_params)

          if supplement.save
            render json: supplement, status: :created
          else
            render_validation_errors(supplement)
          end
        end

        def update
          if @supplement.update(supplement_params)
            render json: @supplement
          else
            render_validation_errors(@supplement)
          end
        end

        def destroy
          @supplement.destroy!
          head :no_content
        end

        private

        def set_supplement
          @supplement = @current_client.supplements.find_by(id: params[:id])
          render_not_found unless @supplement
        end

        def supplement_params
          params.permit(:name, :dosage, :taken_at, :notes)
        end
      end
    end
  end
end
