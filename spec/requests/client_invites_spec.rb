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
    expect(json_response["client"]["id"]).to eq(client.id)
  end

  it "rejects invite acceptance without an invite token" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, password: "originalpass")

    post "/api/v1/client/accept_invite", params: { password: "newpassword123" }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(json_response).to eq({ "error" => "Invalid or expired invite" })
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

    expect(response).to have_http_status(:unauthorized)
    expect(json_response).to eq({ "error" => "Invalid email or password" })
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

    expect(response).to have_http_status(422)
    expect(json_response["errors"]).to include("Password is too short (minimum is 8 characters)")
    expect(client.reload.invite_accepted_at).to be_nil
    expect(client.invite_token).to be_present
  end
end
