require "rails_helper"

RSpec.describe ClientMailer, type: :mailer do
  include RequestHelpers

  around do |example|
    original_invite_url = ENV["CLIENT_INVITE_URL"]
    original_password_reset_url = ENV["CLIENT_PASSWORD_RESET_URL"]

    ENV["CLIENT_INVITE_URL"] = "https://app.example.com/invite"
    ENV["CLIENT_PASSWORD_RESET_URL"] = "https://app.example.com/reset-password"

    example.run
  ensure
    ENV["CLIENT_INVITE_URL"] = original_invite_url
    ENV["CLIENT_PASSWORD_RESET_URL"] = original_password_reset_url
  end

  let(:practitioner) { create_practitioner }

  it "renders an invite email with the recipient and invite token" do
    client = create_client(practitioner: practitioner, accepted: false)

    email = described_class.with(client: client).invite

    expect(email.to).to eq([ client.email ])
    expect(email.subject).to eq("You have been invited to NaturoPath")
    expect(email.body.encoded).to include("https://app.example.com/invite?invite_token=#{client.invite_token}")
    expect(email.body.encoded).to include("This invite expires in 14 days")
  end

  it "renders a password reset email with the recipient and reset token" do
    client = create_client(practitioner: practitioner)
    reset_token = "reset-token-123"

    email = described_class.with(client: client, reset_token: reset_token).password_reset

    expect(email.to).to eq([ client.email ])
    expect(email.subject).to eq("Reset your NaturoPath password")
    expect(email.body.encoded).to include("https://app.example.com/reset-password?reset_token=#{reset_token}")
    expect(email.body.encoded).to include("This link expires in 2 hours")
  end
end
