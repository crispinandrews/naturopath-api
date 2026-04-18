class SymptomSerializer < ApplicationRecordSerializer
  class << self
    private

    def attributes
      %i[id client_id client_uuid name severity occurred_at duration_minutes notes created_at updated_at]
    end
  end
end
