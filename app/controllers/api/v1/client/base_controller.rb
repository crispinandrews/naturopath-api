module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        before_action :authenticate_client!

        private

        def filter_by_date_range(scope, column_name)
          attribute = timestamp_attribute(scope, column_name)
          scope = scope.where(attribute.gteq(parse_date_filter(params[:from], bound: :from))) if params[:from].present?
          scope = scope.where(attribute.lteq(parse_date_filter(params[:to], bound: :to))) if params[:to].present?
          scope
        end

        def timestamp_attribute(scope, column_name)
          column_name = column_name.to_s

          unless scope.klass.column_names.include?(column_name)
            raise ArgumentError, "Unknown timestamp column: #{column_name}"
          end

          scope.klass.arel_table[column_name]
        end

        def parse_date_filter(value, bound:)
          value = value.to_s.strip

          if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            time = Date.iso8601(value).in_time_zone
            return bound == :to ? time.end_of_day : time.beginning_of_day
          end

          Time.zone.parse(value) || raise_invalid_date_filter(bound)
        rescue ArgumentError
          raise_invalid_date_filter(bound)
        end

        def raise_invalid_date_filter(bound)
          raise ApplicationController::InvalidDateFilterError, "Invalid #{bound} date filter"
        end
      end
    end
  end
end
