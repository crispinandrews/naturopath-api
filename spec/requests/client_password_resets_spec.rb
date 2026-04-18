require "rails_helper"

RSpec.describe "Client password reset", type: :request do
  include_context "with test active job adapter"

  let(:practitioner) { create_practitioner }
  let(:client) { create_client(practitioner: practitioner, password: "oldpassword123") }

  it "issues a password reset token and queues an email for an accepted client" do
    expect do
      post "/api/v1/client/forgot_password", params: { email: client.email }, as: :json
    end.to change { PasswordResetToken.count }.by(1)

    expect(response).to have_http_status(:no_content)
    expect(enqueued_jobs.size).to eq(1)
    expect(PasswordResetToken.last.client).to eq(client)
  end

  it "does not reveal unknown emails" do
    expect do
      post "/api/v1/client/forgot_password", params: { email: "missing@example.com" }, as: :json
    end.not_to change { PasswordResetToken.count }

    expect(response).to have_http_status(:no_content)
    expect(enqueued_jobs).to be_empty
  end

  it "resets the password, revokes existing refresh tokens, and returns fresh auth tokens" do
    issued_reset_token = PasswordResetToken.issue_for!(client)
    old_refresh_token = RefreshToken.issue_for!(client)[:record]

    post "/api/v1/client/reset_password",
      params: {
        reset_token: issued_reset_token[:plaintext_token],
        password: "newpassword123"
      },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["refresh_token"]).to be_present
    expect(json_response.dig("client", "id")).to eq(client.id)
    expect(client.reload.authenticate("newpassword123")).to be_truthy
    expect(issued_reset_token[:record].reload.used_at).to be_present
    expect(old_refresh_token.reload.revoked_at).to be_present
  end

  it "rejects an invalid reset token" do
    post "/api/v1/client/reset_password",
      params: {
        reset_token: "not-a-real-token",
        password: "newpassword123"
      },
      as: :json

    expect_error_response(status: :unauthorized, code: "invalid_reset_token", message: "Invalid reset token")
  end

  it "rejects an expired reset token" do
    issued_reset_token = PasswordResetToken.issue_for!(client, expires_at: 1.minute.ago)

    post "/api/v1/client/reset_password",
      params: {
        reset_token: issued_reset_token[:plaintext_token],
        password: "newpassword123"
      },
      as: :json

    expect_error_response(status: :unauthorized, code: "invalid_reset_token", message: "Invalid reset token")
  end

  it "rejects a reused reset token" do
    issued_reset_token = PasswordResetToken.issue_for!(client)

    post "/api/v1/client/reset_password",
      params: {
        reset_token: issued_reset_token[:plaintext_token],
        password: "newpassword123"
      },
      as: :json

    post "/api/v1/client/reset_password",
      params: {
        reset_token: issued_reset_token[:plaintext_token],
        password: "anotherpassword123"
      },
      as: :json

    expect_error_response(status: :unauthorized, code: "invalid_reset_token", message: "Invalid reset token")
  end

  it "rejects an invalid replacement password" do
    issued_reset_token = PasswordResetToken.issue_for!(client)

    post "/api/v1/client/reset_password",
      params: {
        reset_token: issued_reset_token[:plaintext_token],
        password: "short"
      },
      as: :json

    expect_error_response(status: :unprocessable_entity, code: "validation_failed", message: "Validation failed")
    expect(client.reload.authenticate("oldpassword123")).to be_truthy
  end

  it "lets an authenticated client change password with the current password" do
    old_refresh_token = RefreshToken.issue_for!(client)[:record]

    patch "/api/v1/client/password",
      params: {
        current_password: "oldpassword123",
        new_password: "changedpassword123"
      },
      headers: auth_headers_for(client),
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["token"]).to be_present
    expect(json_response["refresh_token"]).to be_present
    expect(json_response.dig("client", "id")).to eq(client.id)
    expect(client.reload.authenticate("changedpassword123")).to be_truthy
    expect(old_refresh_token.reload.revoked_at).to be_present
  end

  it "rejects authenticated password change with the wrong current password" do
    patch "/api/v1/client/password",
      params: {
        current_password: "wrongpassword123",
        new_password: "changedpassword123"
      },
      headers: auth_headers_for(client),
      as: :json

    expect_error_response(status: :unauthorized, code: "invalid_current_password", message: "Invalid current password")
    expect(client.reload.authenticate("oldpassword123")).to be_truthy
  end

  it "rejects authenticated password change with an invalid new password" do
    patch "/api/v1/client/password",
      params: {
        current_password: "oldpassword123",
        new_password: "short"
      },
      headers: auth_headers_for(client),
      as: :json

    expect_error_response(status: :unprocessable_entity, code: "validation_failed", message: "Validation failed")
    expect(client.reload.authenticate("oldpassword123")).to be_truthy
  end
end
