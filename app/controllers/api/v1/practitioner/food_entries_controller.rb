module Api
  module V1
    module Practitioner
      class FoodEntriesController < BaseController
        def index
          entries = filter_by_date_range(@client.food_entries).order(consumed_at: :desc)
          render json: entries
        end
      end
    end
  end
end
