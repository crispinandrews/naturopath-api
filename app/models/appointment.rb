class Appointment < ApplicationRecord
  APPOINTMENT_TYPES = %w[intake follow_up labs_review check_in].freeze
  STATUSES = %w[scheduled completed cancelled no_show].freeze

  belongs_to :client
  belongs_to :practitioner

  validates :scheduled_at, :appointment_type, :status, :duration_minutes, presence: true
  validates :appointment_type, inclusion: { in: APPOINTMENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :duration_minutes, numericality: { greater_than: 0 }
  validate :practitioner_matches_client

  private

  def practitioner_matches_client
    return unless client && practitioner
    return if client.practitioner_id == practitioner_id

    errors.add(:practitioner, "must own the client")
  end
end
