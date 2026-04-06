module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        before_action :authenticate_client!

        private

        def filter_by_date_range(scope)
          scope = scope.where("#{scope.table_name}.created_at >= ?", params[:from]) if params[:from].present?
          scope = scope.where("#{scope.table_name}.created_at <= ?", params[:to]) if params[:to].present?
          scope
        end
      end
    end
  end
end
