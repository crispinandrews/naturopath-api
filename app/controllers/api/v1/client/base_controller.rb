module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        before_action :authenticate_client!

        private

        def filter_by_date_range(scope, column_name)
          attribute = timestamp_attribute(scope, column_name)
          scope = scope.where(attribute.gteq(params[:from])) if params[:from].present?
          scope = scope.where(attribute.lteq(params[:to])) if params[:to].present?
          scope
        end

        def timestamp_attribute(scope, column_name)
          column_name = column_name.to_s

          unless scope.klass.column_names.include?(column_name)
            raise ArgumentError, "Unknown timestamp column: #{column_name}"
          end

          scope.klass.arel_table[column_name]
        end
      end
    end
  end
end
