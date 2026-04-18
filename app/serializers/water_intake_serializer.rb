class WaterIntakeSerializer < ApplicationRecordSerializer
  class << self
    private

    def attributes
      %i[id client_id client_uuid amount_ml recorded_at created_at updated_at]
    end
  end
end
