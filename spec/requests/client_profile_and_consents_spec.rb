require "rails_helper"

RSpec.describe "Client profile and consents", type: :request do
  before do
    @practitioner = create_practitioner(first_name: "Robin", last_name: "Stone", practice_name: "Stone Wellness")
    @client = create_client(
      practitioner: @practitioner,
      first_name: "Casey",
      last_name: "Patient",
      date_of_birth: Date.new(1991, 4, 12)
    )
  end

  it "returns the authenticated client's profile inside a data envelope" do
    get "/api/v1/client/profile", headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(response_data).to include(
      "id" => @client.id,
      "email" => @client.email,
      "first_name" => "Casey",
      "last_name" => "Patient"
    )
    expect(response_data.dig("practitioner", "practice_name")).to eq("Stone Wellness")
  end

  it "updates the authenticated client's profile" do
    patch "/api/v1/client/profile",
      params: {
        first_name: "Morgan",
        last_name: "Updated",
        email: "morgan.updated@example.com",
        date_of_birth: "1992-05-13"
      },
      headers: auth_headers_for(@client),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_data).to include(
      "id" => @client.id,
      "email" => "morgan.updated@example.com",
      "first_name" => "Morgan",
      "last_name" => "Updated"
    )
    expect(@client.reload.date_of_birth).to eq(Date.new(1992, 5, 13))
  end

  it "rejects invalid profile updates" do
    patch "/api/v1/client/profile",
      params: { email: "not-an-email" },
      headers: auth_headers_for(@client),
      as: :json

    expect_error_response(status: :unprocessable_entity, code: "validation_failed", message: "Validation failed")
    expect(json_response.dig("error", "details")).to include("Email is invalid")
  end

  it "lists consents with pagination metadata" do
    2.times do |index|
      @client.consents.create!(
        consent_type: "consent_#{index}",
        version: "1.0",
        granted_at: Time.current - index.hours,
        ip_address: "127.0.0.1"
      )
    end

    get "/api/v1/client/consents",
      params: { page: 1, per_page: 1 },
      headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(response_data.length).to eq(1)
    expect(response_meta).to include(
      "page" => 1,
      "per_page" => 1,
      "total_count" => 2,
      "total_pages" => 2
    )
  end

  it "creates a consent inside a data envelope" do
    post "/api/v1/client/consents",
      params: {
        consent_type: "health_data_processing",
        version: "1.0"
      },
      headers: auth_headers_for(@client),
      as: :json

    expect(response).to have_http_status(:created)
    expect(response_data["consent_type"]).to eq("health_data_processing")
    expect(response_data["ip_address"]).to be_present
  end
end
