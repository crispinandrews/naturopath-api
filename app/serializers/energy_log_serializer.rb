class EnergyLogSerializer < ApplicationRecordSerializer
  class << self
    private

    def attributes
      %i[id client_id client_uuid level recorded_at notes created_at updated_at]
    end
  end
end
