require "rails_helper"

RSpec.describe "Practitioner authentication", type: :request do
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

    expect_error_response(status: :unauthorized, code: "invalid_credentials", message: "Invalid email or password")
  end

  it "rate limits repeated failed practitioner logins" do
    practitioner = create_practitioner(password: "password123")

    10.times do
      post "/api/v1/practitioner/login",
        params: {
          email: practitioner.email,
          password: "wrong-password"
        },
        headers: { "REMOTE_ADDR" => "203.0.113.51" },
        as: :json
    end

    post "/api/v1/practitioner/login",
      params: {
        email: practitioner.email,
        password: "wrong-password"
      },
      headers: { "REMOTE_ADDR" => "203.0.113.51" },
      as: :json

    expect_error_response(status: :too_many_requests, code: "rate_limited", message: "Too many requests. Try again later.")
    expect(response.headers["Retry-After"]).to be_present
  end
end
