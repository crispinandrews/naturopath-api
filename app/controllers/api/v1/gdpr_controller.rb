module Api
  module V1
    class GdprController < BaseController
      before_action :authenticate_client!

      # Right to access — export all client data as JSON
      def export
        data = {
          profile: {
            email: @current_client.email,
            first_name: @current_client.first_name,
            last_name: @current_client.last_name,
            date_of_birth: @current_client.date_of_birth,
            created_at: @current_client.created_at
          },
          food_entries: @current_client.food_entries.order(:consumed_at),
          symptoms: @current_client.symptoms.order(:occurred_at),
          energy_logs: @current_client.energy_logs.order(:recorded_at),
          sleep_logs: @current_client.sleep_logs.order(:bedtime),
          water_intakes: @current_client.water_intakes.order(:recorded_at),
          supplements: @current_client.supplements.order(:taken_at),
          consents: @current_client.consents.order(:created_at)
        }

        AppEventLogger.info("gdpr.data_exported", **request_context(client_id: @current_client.id))
        render json: { exported_at: Time.current, data: data }
      end

      # Right to erasure — delete all client data
      def delete_data
        ApplicationRecord.transaction do
          @current_client.food_entries.destroy_all
          @current_client.symptoms.destroy_all
          @current_client.energy_logs.destroy_all
          @current_client.sleep_logs.destroy_all
          @current_client.water_intakes.destroy_all
          @current_client.supplements.destroy_all

          # Record that deletion was requested (keep consent records for legal compliance)
          @current_client.consents.create!(
            consent_type: "data_deletion_request",
            version: "1.0",
            granted_at: Time.current,
            ip_address: request.remote_ip
          )
        end

        AppEventLogger.info("gdpr.data_deleted", **request_context(client_id: @current_client.id))
        render json: { message: "All health data has been deleted", deleted_at: Time.current }
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end
    end
  end
end
