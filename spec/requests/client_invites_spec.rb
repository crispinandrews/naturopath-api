require "rails_helper"

RSpec.describe "Client invites", type: :request do
  it "rejects invite acceptance without an invite token" do
    suffix = SecureRandom.hex(4)

    practitioner = Practitioner.create!(
      email: "practitioner-#{suffix}@example.com",
      password: "password123",
      first_name: "Pat",
      last_name: "Doctor"
    )
    client = practitioner.clients.create!(
      email: "client-#{suffix}@example.com",
      password: "originalpass",
      first_name: "Casey",
      last_name: "Patient",
      invite_accepted_at: Time.current
    )
    client.update_columns(invite_token: nil)

    post "/api/v1/client/accept_invite", params: { password: "newpassword123" }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to eq({ "error" => "Invalid or expired invite" })
    expect(client.reload.authenticate("originalpass")).to be_truthy
    expect(client.authenticate("newpassword123")).to be(false)
  end
end
