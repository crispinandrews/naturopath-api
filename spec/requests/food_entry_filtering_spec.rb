require "rails_helper"

RSpec.describe "Food entry filtering", type: :request do
  before do
    @practitioner = create_practitioner(first_name: "Fran", last_name: "Healer")
    @client = create_client(
      practitioner: @practitioner,
      first_name: "Taylor",
      last_name: "Client"
    )

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
    expect(response_data.map { |entry| entry["id"] }).to eq([ @included_entry.id ])
  end

  it "filters practitioner food entries by consumed_at" do
    get "/api/v1/clients/#{@client.id}/food_entries",
      params: { from: "2026-04-04T00:00:00Z" },
      headers: auth_headers_for(@practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |entry| entry["id"] }).to eq([ @included_entry.id ])
  end

  it "accepts space-separated datetimes for backward compatibility" do
    get "/api/v1/client/food_entries",
      params: { from: "2026-04-04 00:00:00" },
      headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |entry| entry["id"] }).to eq([ @included_entry.id ])
  end

  it "treats a date-only to filter as inclusive through the end of the day" do
    get "/api/v1/client/food_entries",
      params: { to: "2026-04-05" },
      headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |entry| entry["id"] }).to eq([ @included_entry.id, @excluded_entry.id ])
  end

  it "returns 422 for invalid date filters" do
    get "/api/v1/client/food_entries",
      params: { from: "not-a-date" },
      headers: auth_headers_for(@client)

    expect_error_response(status: 422, code: "invalid_date_filter", message: "Invalid from date filter")
  end

  it "paginates list responses" do
    @client.food_entries.create!(description: "Third entry", consumed_at: Time.zone.parse("2026-04-06 09:00:00"))

    get "/api/v1/client/food_entries",
      params: { page: 2, per_page: 1 },
      headers: auth_headers_for(@client)

    expect(response).to have_http_status(:ok)
    expect(response_data.length).to eq(1)
    expect(response_meta).to include(
      "page" => 2,
      "per_page" => 1,
      "total_count" => 3,
      "total_pages" => 3
    )
  end

  it "returns 422 for invalid pagination params" do
    get "/api/v1/client/food_entries",
      params: { page: 0, per_page: "abc" },
      headers: auth_headers_for(@client)

    expect_error_response(status: 422, code: "invalid_pagination", message: "page must be greater than 0")
  end
end
