module Api
  module V1
    module Practitioner
      class BaseController < Api::V1::BaseController
        before_action :authenticate_practitioner!
        before_action :set_client

        private

        def set_client
          @client = @current_practitioner.clients.find_by(id: params[:client_id])
          render_not_found unless @client
        end

        def filter_by_date_range(scope)
          scope = scope.where("#{scope.table_name}.created_at >= ?", params[:from]) if params[:from].present?
          scope = scope.where("#{scope.table_name}.created_at <= ?", params[:to]) if params[:to].present?
          scope
        end
      end
    end
  end
end
