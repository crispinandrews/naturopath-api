require "rails_helper"

RSpec.describe "Practitioner authentication", type: :request do
  it "registers a practitioner" do
    post "/api/v1/practitioner/register",
      params: {
        email: unique_email("registered-practitioner"),
        password: "password123",
        password_confirmation: "password123",
        first_name: "Robin",
        last_name: "Stone",
        practice_name: "Stone Wellness"
      },
      as: :json

    expect(response).to have_http_status(:created)
    expect(json_response["token"]).to be_present
    expect(json_response["practitioner"]["practice_name"]).to eq("Stone Wellness")
  end

  it "rejects invalid registration params" do
    post "/api/v1/practitioner/register",
      params: {
        email: "not-an-email",
        password: "short",
        password_confirmation: "mismatch",
        first_name: "",
        last_name: ""
      },
      as: :json

    expect(response).to have_http_status(422)
    expect(json_response["errors"]).not_to be_empty
  end

  it "logs in an existing practitioner" do
    practitioner = create_practitioner(password: "password123")

    post "/api/v1/practitioner/login",
      params: {
        email: practitioner.email,
        password: "password123"
      },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["practitioner"]["id"]).to eq(practitioner.id)
  end

  it "rejects invalid practitioner credentials" do
    practitioner = create_practitioner(password: "password123")

    post "/api/v1/practitioner/login",
      params: {
        email: practitioner.email,
        password: "wrong-password"
      },
      as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(json_response).to eq({ "error" => "Invalid email or password" })
  end
end
