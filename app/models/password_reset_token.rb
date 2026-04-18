require "digest"

class PasswordResetToken < ApplicationRecord
  TTL = 2.hours

  class InvalidTokenError < StandardError; end

  belongs_to :client

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def self.issue_for!(client, expires_at: TTL.from_now)
    plaintext_token = generate_plaintext_token

    client.password_reset_tokens.active.update_all(used_at: Time.current, updated_at: Time.current)
    password_reset_token = create!(
      client: client,
      token_digest: digest(plaintext_token),
      expires_at: expires_at
    )

    { record: password_reset_token, plaintext_token: plaintext_token }
  end

  def self.find_by_plaintext(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest("#{digest_secret}:#{token}")
  end

  def expired?
    expires_at <= Time.current
  end

  def used?
    used_at.present?
  end

  def active?
    !used? && !expired?
  end

  def reset_password!(password:)
    with_lock do
      raise InvalidTokenError unless active?

      client.update!(password: password)
      update!(used_at: Time.current)
      client.refresh_tokens.active.find_each(&:revoke!)
      client
    end
  end

  private

  def self.generate_plaintext_token
    SecureRandom.urlsafe_base64(48)
  end

  def self.digest_secret
    ENV["PASSWORD_RESET_TOKEN_SECRET"].presence || Rails.application.secret_key_base
  end
end
