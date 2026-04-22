class PractitionerNoteSerializer < ApplicationRecordSerializer
  class << self
    private

    def attributes
      %i[id client_id author_id note_type body pinned created_at updated_at]
    end
  end
end
