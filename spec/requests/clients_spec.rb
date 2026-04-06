require "rails_helper"

RSpec.describe "Practitioner client management", type: :request do
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
    expect(json_response.map { |client| client["id"] }).to eq([ own_client.id ])
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
    expect(json_response["invite_token"]).to be_present
    expect(json_response["invite_accepted"]).to be(false)
    expect(json_response["invite_expires_at"]).to be_present
  end

  it "shows an owned client" do
    practitioner = create_practitioner
    client = create_client(practitioner: practitioner)

    get "/api/v1/clients/#{client.id}", headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:ok)
    expect(json_response["id"]).to eq(client.id)
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
end
