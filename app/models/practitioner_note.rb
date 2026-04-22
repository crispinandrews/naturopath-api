class PractitionerNote < ApplicationRecord
  NOTE_TYPES = %w[session intake message observation].freeze

  belongs_to :client
  belongs_to :author, class_name: "Practitioner"

  validates :note_type, presence: true, inclusion: { in: NOTE_TYPES }
  validates :body, presence: true
  validate :author_matches_client_practitioner

  private

  def author_matches_client_practitioner
    return unless client && author
    return if client.practitioner_id == author_id

    errors.add(:author, "must own the client")
  end
end
