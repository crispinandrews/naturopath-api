class ConsentSerializer < ApplicationRecordSerializer
  class << self
    private

    def attributes
      %i[id client_id consent_type version granted_at revoked_at ip_address created_at updated_at]
    end
  end
end
