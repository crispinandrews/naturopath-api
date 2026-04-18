class Client < ApplicationRecord
  INVITE_TTL = 14.days
  ExpiredInviteError = Class.new(StandardError)
  InviteAlreadyAcceptedError = Class.new(StandardError)

  has_secure_password validations: false

  belongs_to :practitioner
  has_many :food_entries, dependent: :destroy
  has_many :symptoms, dependent: :destroy
  has_many :energy_logs, dependent: :destroy
  has_many :sleep_logs, dependent: :destroy
  has_many :water_intakes, dependent: :destroy
  has_many :supplements, dependent: :destroy
  has_many :consents, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy
  has_many :password_reset_tokens, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :invite_expires_at, presence: true, if: :pending_invite?

  normalizes :email, with: ->(email) { email.strip.downcase }

  before_validation :generate_invite_token, on: :create
  before_validation :set_invite_expiry, on: :create

  def full_name
    "#{first_name} #{last_name}"
  end

  def invited?
    pending_invite? && !invite_expired?
  end

  def invite_expired?
    invite_expires_at.present? && invite_expires_at <= Time.current
  end

  def accept_invite!(password:)
    raise ExpiredInviteError if invite_expired?

    update!(
      password: password,
      invite_accepted_at: Time.current,
      invite_token: nil,
      invite_expires_at: nil
    )
  end

  def refresh_invite!
    raise InviteAlreadyAcceptedError if invite_accepted_at.present?

    update!(
      invite_token: SecureRandom.urlsafe_base64(32),
      invite_expires_at: INVITE_TTL.from_now
    )
  end

  private

  def generate_invite_token
    self.invite_token ||= SecureRandom.urlsafe_base64(32) if invite_accepted_at.nil?
  end

  def set_invite_expiry
    self.invite_expires_at ||= INVITE_TTL.from_now if pending_invite?
  end

  def password_required?
    password.present? || password_digest_changed?
  end

  def pending_invite?
    invite_token.present? && invite_accepted_at.nil?
  end
end
