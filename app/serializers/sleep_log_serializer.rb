class SleepLogSerializer < ApplicationRecordSerializer
  class << self
    private

    def attributes
      %i[id client_id client_uuid bedtime wake_time quality hours_slept notes created_at updated_at]
    end
  end
end
