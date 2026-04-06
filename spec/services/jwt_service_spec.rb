require "rails_helper"

RSpec.describe JwtService do
  around do |example|
    original_env = ENV.to_hash.slice(
      "JWT_SECRET_KEY",
      "JWT_PREVIOUS_SECRET_KEY",
      "JWT_KEY_VERSION",
      "JWT_PREVIOUS_KEY_VERSION",
      "JWT_ISSUER",
      "JWT_AUDIENCE"
    )

    ENV["JWT_SECRET_KEY"] = "current-secret"
    ENV["JWT_PREVIOUS_SECRET_KEY"] = "previous-secret"
    ENV["JWT_KEY_VERSION"] = "v2"
    ENV["JWT_PREVIOUS_KEY_VERSION"] = "v1"
    ENV["JWT_ISSUER"] = "naturopath-api-test"
    ENV["JWT_AUDIENCE"] = "naturopath-mobile-test"

    example.run
  ensure
    %w[
      JWT_SECRET_KEY
      JWT_PREVIOUS_SECRET_KEY
      JWT_KEY_VERSION
      JWT_PREVIOUS_KEY_VERSION
      JWT_ISSUER
      JWT_AUDIENCE
    ].each do |key|
      ENV[key] = original_env[key]
    end
  end

  it "encodes claims with issuer, audience, and key version metadata" do
    token = described_class.encode(user_id: 42, user_type: "Client")
    payload, header = JWT.decode(token, nil, false)

    expect(header["kid"]).to eq("v2")
    expect(payload["iss"]).to eq("naturopath-api-test")
    expect(payload["aud"]).to eq("naturopath-mobile-test")
    expect(payload["jti"]).to be_present
    expect(payload["iat"]).to be_present
  end

  it "accepts tokens signed with the previous secret during key rotation" do
    claims = {
      user_id: 7,
      user_type: "Practitioner",
      exp: 1.hour.from_now.to_i,
      iss: "naturopath-api-test",
      aud: "naturopath-mobile-test",
      iat: Time.current.to_i,
      jti: SecureRandom.uuid
    }
    token = JWT.encode(claims, "previous-secret", "HS256", { kid: "v1" })

    result = described_class.decode(token)

    expect(result[:error]).to be_nil
    expect(result[:payload][:user_id]).to eq(7)
    expect(result[:payload][:user_type]).to eq("Practitioner")
  end

  it "rejects tokens with the wrong audience" do
    claims = {
      user_id: 9,
      user_type: "Client",
      exp: 1.hour.from_now.to_i,
      iss: "naturopath-api-test",
      aud: "wrong-audience",
      iat: Time.current.to_i,
      jti: SecureRandom.uuid
    }
    token = JWT.encode(claims, "current-secret", "HS256", { kid: "v2" })

    result = described_class.decode(token)

    expect(result[:payload]).to be_nil
    expect(result[:error]).to eq(:invalid_token)
  end
end
