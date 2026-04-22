module Api
  module V1
    module Practitioner
      class AppointmentsController < BaseController
        before_action :set_appointment, only: [ :show, :update, :destroy ]

        def index
          scope = @client.appointments.order(scheduled_at: :desc)
          records, meta = paginate(scope)
          render_collection(records, serializer: AppointmentSerializer, meta: meta)
        end

        def show
          render_resource(@appointment, serializer: AppointmentSerializer)
        end

        def create
          appt = @client.appointments.new(appointment_params.merge(practitioner: @current_practitioner))
          if appt.save
            render_resource(appt, serializer: AppointmentSerializer, status: :created)
          else
            render_validation_errors(appt)
          end
        end

        def update
          if @appointment.update(appointment_params)
            render_resource(@appointment, serializer: AppointmentSerializer)
          else
            render_validation_errors(@appointment)
          end
        end

        def destroy
          @appointment.destroy!
          head :no_content
        end

        private

        def set_appointment
          @appointment = @client.appointments.find_by(id: params[:id])
          render_not_found unless @appointment
        end

        def appointment_params
          params.permit(:scheduled_at, :duration_minutes, :appointment_type, :status, :notes)
        end
      end
    end
  end
end
