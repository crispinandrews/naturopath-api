class AppointmentSerializer
  class << self
    def collection(records, context: nil)
      records.map { |record| as_json(record, context: context) }
    end

    def as_json(appointment, context: nil)
      payload = appointment.as_json(
        only: %i[id client_id practitioner_id scheduled_at duration_minutes
                 appointment_type status notes created_at updated_at]
      ).deep_symbolize_keys

      payload[:client] = client_payload(appointment.client) if context == :schedule
      payload
    end

    private

    def client_payload(client)
      return nil unless client

      {
        id: client.id,
        first_name: client.first_name,
        last_name: client.last_name,
        focus_tag: client.focus_tag
      }
    end
  end
end
