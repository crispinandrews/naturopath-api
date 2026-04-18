require "digest"

class RefreshToken < ApplicationRecord
  TTL = 30.days

  class InvalidTokenError < StandardError; end

  belongs_to :client
  belongs_to :replaced_by_token, class_name: "RefreshToken", optional: true

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.issue_for!(client, expires_at: TTL.from_now)
    plaintext_token = generate_plaintext_token
    refresh_token = create!(
      client: client,
      token_digest: digest(plaintext_token),
      expires_at: expires_at
    )

    { record: refresh_token, plaintext_token: plaintext_token }
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

  def revoked?
    revoked_at.present?
  end

  def active?
    !revoked? && !expired?
  end

  def rotate!
    with_lock do
      raise InvalidTokenError unless active?

      replacement = self.class.issue_for!(client)
      update!(
        revoked_at: Time.current,
        last_used_at: Time.current,
        replaced_by_token: replacement[:record]
      )

      replacement
    end
  end

  def revoke!
    with_lock do
      return if revoked?

      update!(revoked_at: Time.current)
    end
  end

  private

  def self.generate_plaintext_token
    SecureRandom.urlsafe_base64(48)
  end

  def self.digest_secret
    ENV["REFRESH_TOKEN_SECRET"].presence || Rails.application.secret_key_base
  end
end
