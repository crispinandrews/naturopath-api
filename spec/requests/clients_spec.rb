require "rails_helper"

RSpec.describe "Practitioner client management", type: :request do
  include_context "with test active job adapter"

  it "requires practitioner authentication" do
    get "/api/v1/clients"

    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "lists only the practitioner's own clients" do
    practitioner = create_practitioner
    other_practitioner = create_practitioner
    own_client = create_client(practitioner: practitioner, first_name: "Alice")
    create_client(practitioner: other_practitioner, first_name: "Bob")

    get "/api/v1/clients", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |client| client["id"] }).to eq([ own_client.id ])
    expect(response_meta).to include(
      "page" => 1,
      "per_page" => 50,
      "total_count" => 1,
      "total_pages" => 1
    )
  end

  it "returns empty pagination metadata when the practitioner has no clients" do
    practitioner = create_practitioner

    get "/api/v1/clients", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data).to eq([])
    expect(response_meta).to include(
      "page" => 1,
      "per_page" => 50,
      "total_count" => 0,
      "total_pages" => 0
    )
  end

  it "creates a pending client invite" do
    practitioner = create_practitioner

    expect do
      post "/api/v1/clients",
        params: {
          email: unique_email("new-client"),
          first_name: "Nina",
          last_name: "Jones",
          date_of_birth: "1993-01-15"
        },
        headers: auth_headers_for(practitioner),
        as: :json
    end.to change(Client, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response_data["invite_token"]).to be_present
    expect(response_data["invite_accepted"]).to be(false)
    expect(response_data["invite_expires_at"]).to be_present
    expect(enqueued_jobs.size).to eq(1)
  end

  it "shows an owned client" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    get "/api/v1/clients/#{client.id}", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data["id"]).to eq(client.id)
    expect(response_data["invite_token"]).to be_nil
    expect(response_data).not_to have_key("invite_expires_at")
  end

  it "returns not found for another practitioner's client" do
    practitioner = create_practitioner
    other_practitioner = create_practitioner
    foreign_client = create_client(practitioner: other_practitioner)

    get "/api/v1/clients/#{foreign_client.id}", headers: auth_headers_for(practitioner)

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end

  it "updates an owned client" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, first_name: "Before")

    patch "/api/v1/clients/#{client.id}",
      params: {
        first_name: "After",
        last_name: "Updated"
      },
      headers: auth_headers_for(practitioner),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data["first_name"]).to eq("After")
    expect(client.reload.first_name).to eq("After")
    expect(client.last_name).to eq("Updated")
  end

  it "rejects invalid client updates" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    patch "/api/v1/clients/#{client.id}",
      params: { email: "bad-email" },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include("Email is invalid")
  end

  it "deletes an owned client" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    expect do
      delete "/api/v1/clients/#{client.id}", headers: auth_headers_for(practitioner)
    end.to change(Client, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end

  it "resends an invite for a pending client and rotates the token" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner, accepted: false)
    old_token = client.invite_token
    old_expiry = client.invite_expires_at

    post "/api/v1/clients/#{client.id}/resend_invite", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data["invite_token"]).to be_present
    expect(response_data["invite_token"]).not_to eq(old_token)
    expect(Time.zone.parse(response_data["invite_expires_at"])).to be > old_expiry
    expect(client.reload.invite_token).to eq(response_data["invite_token"])
    expect(enqueued_jobs.size).to eq(1)
  end

  it "rejects invite resend for an already accepted client" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    post "/api/v1/clients/#{client.id}/resend_invite", headers: auth_headers_for(practitioner)

    expect_error_response(
      status: 422,
      code: "invite_already_accepted",
      message: "Invite has already been accepted"
    )
  end

  it "returns not found when resending an invite for another practitioner's client" do
    practitioner = create_practitioner
    other_practitioner = create_practitioner
    foreign_client = create_client(practitioner: other_practitioner, accepted: false)

    post "/api/v1/clients/#{foreign_client.id}/resend_invite", headers: auth_headers_for(practitioner)

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end

  it "includes focus_tag in the client response" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)
    client.update!(focus_tag: "gut health")

    get "/api/v1/clients/#{client.id}", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data["focus_tag"]).to eq("gut health")
  end

  it "returns focus_tag as nil when not set" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    get "/api/v1/clients/#{client.id}", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data["focus_tag"]).to be_nil
  end

  it "updates focus_tag via PATCH" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    patch "/api/v1/clients/#{client.id}",
      params: { focus_tag: "energy & sleep" },
      headers: auth_headers_for(practitioner),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data["focus_tag"]).to eq("energy & sleep")
    expect(client.reload.focus_tag).to eq("energy & sleep")
  end

  it "rejects focus_tag longer than 80 characters" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    patch "/api/v1/clients/#{client.id}",
      params: { focus_tag: "x" * 81 },
      headers: auth_headers_for(practitioner),
      as: :json

    expect_error_response(status: 422, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include(match(/focus tag/i))
  end
end
