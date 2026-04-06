class JwtService
  ALGORITHM = "HS256"
  CURRENT_KEY_ID = "current"
  PREVIOUS_KEY_ID = "previous"

  def self.encode(payload = nil, exp: 24.hours.from_now, **claims)
    payload = (payload || {}).merge(claims)
    encoded_claims = payload.merge(
      exp: exp.to_i,
      iss: issuer,
      aud: audience,
      iat: Time.current.to_i,
      jti: SecureRandom.uuid
    )

    JWT.encode(encoded_claims, current_secret, ALGORITHM, { kid: current_key_id })
  end

  def self.decode(token)
    candidate_secrets(token).each do |secret|
      decoded = JWT.decode(
        token,
        secret,
        true,
        algorithm: ALGORITHM,
        verify_iss: true,
        iss: issuer,
        verify_aud: true,
        aud: audience
      )

      return { payload: HashWithIndifferentAccess.new(decoded.first), error: nil }
    rescue JWT::ExpiredSignature
      return { payload: nil, error: :expired_token }
    rescue JWT::InvalidIssuerError, JWT::InvalidAudError
      return { payload: nil, error: :invalid_token }
    rescue JWT::DecodeError
      next
    end

    { payload: nil, error: :invalid_token }
  end

  def self.current_key_id
    ENV.fetch("JWT_KEY_VERSION", CURRENT_KEY_ID)
  end

  def self.previous_key_id
    ENV.fetch("JWT_PREVIOUS_KEY_VERSION", PREVIOUS_KEY_ID)
  end

  def self.issuer
    ENV.fetch("JWT_ISSUER", "naturopath-api")
  end

  def self.audience
    ENV.fetch("JWT_AUDIENCE", "naturopath-api-clients")
  end

  def self.current_secret
    ENV["JWT_SECRET_KEY"].presence || fallback_secret
  end

  def self.previous_secret
    ENV["JWT_PREVIOUS_SECRET_KEY"].presence
  end

  def self.fallback_secret
    return Rails.application.secret_key_base unless Rails.env.production?

    raise "JWT_SECRET_KEY must be configured in production"
  end

  def self.candidate_secrets(token)
    key_id = unverified_header(token)["kid"]
    secrets = case key_id
    when current_key_id
      [ current_secret, previous_secret ]
    when previous_key_id
      [ previous_secret, current_secret ]
    else
      [ current_secret, previous_secret ]
    end

    secrets.compact.uniq
  end

  def self.unverified_header(token)
    _payload, header = JWT.decode(token, nil, false)
    header
  rescue JWT::DecodeError
    {}
  end
end
