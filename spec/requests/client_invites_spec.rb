require "rails_helper"

RSpec.describe "Client invites", type: :request do
  it "accepts a valid invite and allows login afterwards" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false)

    post "/api/v1/client/accept_invite",
      params: {
        invite_token: client.invite_token,
        password: "newpassword123"
      },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["refresh_token"]).to be_present
    expect(json_response["client"]["id"]).to eq(client.id)
    expect(client.reload.invite_accepted_at).to be_present
    expect(client.invite_token).to be_nil
    expect(client.authenticate("newpassword123")).to be_truthy

    post "/api/v1/client/login",
      params: {
        email: client.email,
        password: "newpassword123"
      },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["refresh_token"]).to be_present
    expect(json_response["client"]["id"]).to eq(client.id)
  end

  it "rejects invite acceptance without an invite token" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, password: "originalpass")

    post "/api/v1/client/accept_invite", params: { password: "newpassword123" }, as: :json

    expect_error_response(status: :not_found, code: "invite_not_found", message: "Invalid invite")
    expect(client.reload.authenticate("originalpass")).to be_truthy
    expect(client.authenticate("newpassword123")).to be(false)
  end

  it "rejects client login before invite acceptance" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false)

    post "/api/v1/client/login",
      params: {
        email: client.email,
        password: "password123"
      },
      as: :json

    expect_error_response(status: :unauthorized, code: "invalid_credentials", message: "Invalid email or password")
  end

  it "rejects invite acceptance with an invalid password" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false)

    post "/api/v1/client/accept_invite",
      params: {
        invite_token: client.invite_token,
        password: "short"
      },
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include("Password is too short (minimum is 8 characters)")
    expect(client.reload.invite_accepted_at).to be_nil
    expect(client.invite_token).to be_present
  end

  it "rejects expired invites" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false, invite_expires_at: 1.hour.ago)

    post "/api/v1/client/accept_invite",
      params: {
        invite_token: client.invite_token,
        password: "newpassword123"
      },
      as: :json

    expect_error_response(status: :gone, code: "invite_expired", message: "Invite has expired")
    expect(client.reload.invite_accepted_at).to be_nil
  end

  it "rate limits repeated invite acceptance attempts" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false)

    5.times do
      post "/api/v1/client/accept_invite",
        params: { invite_token: client.invite_token, password: "short" },
        headers: { "REMOTE_ADDR" => "203.0.113.50" },
        as: :json
    end

    post "/api/v1/client/accept_invite",
      params: { invite_token: client.invite_token, password: "short" },
      headers: { "REMOTE_ADDR" => "203.0.113.50" },
      as: :json

    expect_error_response(status: :too_many_requests, code: "rate_limited", message: "Too many requests. Try again later.")
    expect(response.headers["Retry-After"]).to be_present
  end
end
