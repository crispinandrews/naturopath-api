class Client < ApplicationRecord
  has_secure_password validations: false

  belongs_to :practitioner
  has_many :food_entries, dependent: :destroy
  has_many :symptoms, dependent: :destroy
  has_many :energy_logs, dependent: :destroy
  has_many :sleep_logs, dependent: :destroy
  has_many :water_intakes, dependent: :destroy
  has_many :supplements, dependent: :destroy
  has_many :consents, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?

  normalizes :email, with: ->(email) { email.strip.downcase }

  before_create :generate_invite_token

  def full_name
    "#{first_name} #{last_name}"
  end

  def invited?
    invite_token.present? && invite_accepted_at.nil?
  end

  def accept_invite!(password:)
    update!(password: password, invite_accepted_at: Time.current, invite_token: nil)
  end

  private

  def generate_invite_token
    self.invite_token = SecureRandom.urlsafe_base64(32)
  end

  def password_required?
    invite_accepted_at.present? || password_digest_changed?
  end
end
