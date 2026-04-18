require "rails_helper"

RSpec.describe "Client refresh tokens", type: :request do
  it "returns a refresh token when a client logs in" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, password: "password123")

    post "/api/v1/client/login",
      params: {
        email: client.email,
        password: "password123"
      },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["refresh_token"]).to be_present

    stored_token = RefreshToken.find_by_plaintext(json_response["refresh_token"])
    expect(stored_token).to be_present
    expect(stored_token.client_id).to eq(client.id)
  end

  it "rotates the refresh token and issues a new access token" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    initial_token = RefreshToken.issue_for!(client)

    post "/api/v1/client/refresh",
      params: { refresh_token: initial_token[:plaintext_token] },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["refresh_token"]).to be_present
    expect(json_response["refresh_token"]).not_to eq(initial_token[:plaintext_token])
    expect(json_response.dig("client", "id")).to eq(client.id)

    old_record = initial_token[:record].reload
    new_record = RefreshToken.find_by_plaintext(json_response["refresh_token"])

    expect(old_record.revoked_at).to be_present
    expect(old_record.replaced_by_token_id).to eq(new_record.id)
    expect(old_record.last_used_at).to be_present
    expect(new_record.client_id).to eq(client.id)
  end

  it "rejects an invalid refresh token" do
    post "/api/v1/client/refresh",
      params: { refresh_token: "not-a-real-token" },
      as: :json

    expect_error_response(
      status: :unauthorized,
      code: "invalid_refresh_token",
      message: "Invalid refresh token"
    )
  end

  it "rejects an expired refresh token" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    expired_token = RefreshToken.issue_for!(client, expires_at: 1.minute.ago)

    post "/api/v1/client/refresh",
      params: { refresh_token: expired_token[:plaintext_token] },
      as: :json

    expect_error_response(
      status: :unauthorized,
      code: "invalid_refresh_token",
      message: "Invalid refresh token"
    )
  end

  it "rejects a reused refresh token after rotation" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    initial_token = RefreshToken.issue_for!(client)

    post "/api/v1/client/refresh",
      params: { refresh_token: initial_token[:plaintext_token] },
      as: :json

    expect(response).to have_http_status(:ok)

    post "/api/v1/client/refresh",
      params: { refresh_token: initial_token[:plaintext_token] },
      as: :json

    expect_error_response(
      status: :unauthorized,
      code: "invalid_refresh_token",
      message: "Invalid refresh token"
    )
  end

  it "revokes a refresh token on logout" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    issued_token = RefreshToken.issue_for!(client)

    post "/api/v1/client/logout",
      params: { refresh_token: issued_token[:plaintext_token] },
      as: :json

    expect(response).to have_http_status(:no_content)
    expect(issued_token[:record].reload.revoked_at).to be_present

    post "/api/v1/client/refresh",
      params: { refresh_token: issued_token[:plaintext_token] },
      as: :json

    expect_error_response(
      status: :unauthorized,
      code: "invalid_refresh_token",
      message: "Invalid refresh token"
    )
  end
end
