require "rails_helper"

RSpec.describe "Food entry filtering", type: :request do
  before do
    suffix = SecureRandom.hex(4)

    @practitioner = Practitioner.create!(
      email: "filter-practitioner-#{suffix}@example.com",
      password: "password123",
      first_name: "Fran",
      last_name: "Healer"
    )
    @client = @practitioner.clients.create!(
      email: "filter-client-#{suffix}@example.com",
      password: "password123",
      first_name: "Taylor",
      last_name: "Client",
      invite_accepted_at: Time.current
    )
    @client.update_columns(invite_token: nil)

    @included_entry = @client.food_entries.create!(
      description: "Included entry",
      consumed_at: Time.zone.parse("2026-04-05 09:00:00")
    )
    @included_entry.update_columns(
      created_at: Time.zone.parse("2026-04-01 09:00:00"),
      updated_at: Time.zone.parse("2026-04-01 09:00:00")
    )

    @excluded_entry = @client.food_entries.create!(
      description: "Excluded entry",
      consumed_at: Time.zone.parse("2026-04-01 09:00:00")
    )
    @excluded_entry.update_columns(
      created_at: Time.zone.parse("2026-04-05 09:00:00"),
      updated_at: Time.zone.parse("2026-04-05 09:00:00")
    )
  end

  it "filters client food entries by consumed_at" do
    get "/api/v1/client/food_entries",
      params: { from: "2026-04-04T00:00:00Z" },
      headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.map { |entry| entry["id"] }).to eq([ @included_entry.id ])
  end

  it "filters practitioner food entries by consumed_at" do
    get "/api/v1/clients/#{@client.id}/food_entries",
      params: { from: "2026-04-04T00:00:00Z" },
      headers: auth_headers_for(@practitioner)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.map { |entry| entry["id"] }).to eq([ @included_entry.id ])
  end
end
