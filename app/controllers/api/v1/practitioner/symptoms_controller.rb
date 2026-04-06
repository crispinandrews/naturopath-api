module Api
  module V1
    module Practitioner
      class SymptomsController < BaseController
        def index
          symptoms = filter_by_date_range(@client.symptoms, :occurred_at).order(occurred_at: :desc)
          render json: symptoms
        end
      end
    end
  end
end
