module Api
  module V1
    module Client
      class FoodEntriesController < BaseController
        before_action :set_food_entry, only: [:show, :update, :destroy]

        def index
          entries = filter_by_date_range(@current_client.food_entries).order(consumed_at: :desc)
          render json: entries
        end

        def show
          render json: @food_entry
        end

        def create
          entry = @current_client.food_entries.new(food_entry_params)

          if entry.save
            render json: entry, status: :created
          else
            render_validation_errors(entry)
          end
        end

        def update
          if @food_entry.update(food_entry_params)
            render json: @food_entry
          else
            render_validation_errors(@food_entry)
          end
        end

        def destroy
          @food_entry.destroy!
          head :no_content
        end

        private

        def set_food_entry
          @food_entry = @current_client.food_entries.find_by(id: params[:id])
          render_not_found unless @food_entry
        end

        def food_entry_params
          params.permit(:meal_type, :description, :consumed_at, :notes)
        end
      end
    end
  end
end
