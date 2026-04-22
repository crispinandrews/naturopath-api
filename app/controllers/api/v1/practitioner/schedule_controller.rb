module Api
  module V1
    module Practitioner
      class ScheduleController < Api::V1::BaseController
        include TimestampFilterable

        before_action :authenticate_practitioner!

        def index
          scope = base_scope
          scope = scope.where(status: status_filter) if status_filter
          scope = filter_by_date_range(scope, :scheduled_at) if params[:from].present? || params[:to].present?
          scope = scope.order(scheduled_at: :asc)
          records, meta = paginate(scope)
          render_collection(records, serializer: AppointmentSerializer, meta: meta)
        end

        def upcoming
          limit = upcoming_limit
          records = base_scope
            .where(status: "scheduled")
            .where("scheduled_at > ?", Time.current)
            .order(scheduled_at: :asc)
            .limit(limit)
          render json: { data: AppointmentSerializer.collection(records, context: serializer_context) }
        end

        private

        def base_scope
          @current_practitioner.appointments.includes(:client)
        end

        def serializer_context
          :schedule
        end

        def status_filter
          return if params[:status].blank?
          return params[:status] if Appointment::STATUSES.include?(params[:status])

          raise ApplicationController::InvalidParameterError,
                "Invalid status. Expected one of: #{Appointment::STATUSES.join(', ')}"
        end

        def upcoming_limit
          return 10 if params[:limit].blank?

          limit = Integer(params[:limit], 10)
          raise ApplicationController::InvalidParameterError, "limit must be greater than 0" unless limit.positive?
          raise ApplicationController::InvalidParameterError, "limit must be less than or equal to 50" if limit > 50

          limit
        rescue ArgumentError
          raise ApplicationController::InvalidParameterError, "limit must be an integer"
        end
      end
    end
  end
end
