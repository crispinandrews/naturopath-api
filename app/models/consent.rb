class Consent < ApplicationRecord
  belongs_to :client

  validates :consent_type, presence: true
  validates :version, presence: true
  validates :granted_at, presence: true

  scope :active, -> { where(revoked_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
