module Api
  module V1
    module Practitioner
      class DailyAggregatesController < BaseController
        def show
          from    = parse_date_param!(params.require(:from), field: :from)
          to      = parse_date_param!(params.require(:to), field: :to)
          tz      = params.fetch(:tz, "UTC")
          metrics = parse_metrics_param!

          if from > to
            raise ApplicationController::InvalidParameterError, "'from' must be on or before 'to'"
          end

          data = DailyAggregateService.new(
            @client,
            from: from, to: to, tz_name: tz, metrics: metrics
          ).call

          render json: {
            data: data,
            meta: { from: from.iso8601, to: to.iso8601, client_id: @client.id }
          }
        end

        private

        def parse_date_param!(value, field:)
          Date.iso8601(value.to_s)
        rescue ArgumentError
          raise ApplicationController::InvalidParameterError, "'#{field}' must be an ISO 8601 date"
        end

        def parse_metrics_param!
          return DailyAggregateService::METRIC_CONFIG.keys.map(&:to_s) if params[:metrics].blank?

          metrics = params[:metrics].split(",").map(&:strip).reject(&:blank?)
          valid_metrics = DailyAggregateService::METRIC_CONFIG.keys.map(&:to_s)
          invalid_metrics = metrics - valid_metrics

          if metrics.empty?
            raise ApplicationController::InvalidParameterError, "At least one metric must be provided"
          end

          return metrics if invalid_metrics.empty?

          raise ApplicationController::InvalidParameterError,
                "Unknown metrics: #{invalid_metrics.join(', ')}"
        end
      end
    end
  end
end
