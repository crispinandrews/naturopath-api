require "rails_helper"

RSpec.describe "Daily aggregates", type: :request do
  let(:practitioner) { create_practitioner }
  let(:client) { create_client(practitioner: practitioner) }

  def get_aggregates(client_id:, headers:, **params)
    get "/api/v1/clients/#{client_id}/daily_aggregates",
      params: { from: "2026-04-01", to: "2026-04-03" }.merge(params),
      headers: headers
  end

  it "requires practitioner authentication" do
    get_aggregates(client_id: client.id, headers: {})

    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "returns 404 for another practitioner's client" do
    other_practitioner = create_practitioner
    foreign_client = create_client(practitioner: other_practitioner)

    get_aggregates(client_id: foreign_client.id,
                   headers: auth_headers_for(practitioner))

    expect_error_response(status: :not_found, code: "not_found", message: "Not found")
  end

  it "requires from and to params" do
    get "/api/v1/clients/#{client.id}/daily_aggregates",
      headers: auth_headers_for(practitioner)

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects an invalid from date" do
    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "nope", to: "2026-04-03" },
      headers: auth_headers_for(practitioner)

    expect_error_response(status: 422, code: "invalid_parameter", message: "'from' must be an ISO 8601 date")
  end

  it "rejects a reversed date range" do
    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "2026-04-03", to: "2026-04-01" },
      headers: auth_headers_for(practitioner)

    expect_error_response(status: 422, code: "invalid_parameter", message: "'from' must be on or before 'to'")
  end

  it "rejects unknown metrics" do
    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "2026-04-01", to: "2026-04-03", metrics: "energy,mood" },
      headers: auth_headers_for(practitioner)

    expect_error_response(status: 422, code: "invalid_parameter", message: "Unknown metrics: mood")
  end

  it "returns one row per day in range with all nulls when no data" do
    get_aggregates(client_id: client.id,
                   headers: auth_headers_for(practitioner))

    expect(response).to have_http_status(:ok)
    data = response_data
    expect(data.size).to eq(3)
    expect(data.map { |r| r["date"] }).to eq(%w[2026-04-01 2026-04-02 2026-04-03])
    expect(data.first.slice("sleep_hours", "energy_level", "symptom_count",
                            "water_ml", "food_entries", "supplement_doses")
          .values).to all(be_nil)
  end

  it "returns correct meta" do
    get_aggregates(client_id: client.id,
                   headers: auth_headers_for(practitioner))

    expect(response_meta).to include(
      "from" => "2026-04-01",
      "to" => "2026-04-03",
      "client_id" => client.id
    )
  end

  it "aggregates sleep_hours for the day" do
    client.sleep_logs.create!(
      bedtime: Time.zone.parse("2026-04-01 22:00"),
      wake_time: Time.zone.parse("2026-04-02 06:00"),
      hours_slept: 8.0
    )
    client.sleep_logs.create!(
      bedtime: Time.zone.parse("2026-04-01 13:00"),
      wake_time: Time.zone.parse("2026-04-01 14:00"),
      hours_slept: 1.0
    )

    get_aggregates(client_id: client.id,
                   headers: auth_headers_for(practitioner))

    row = response_data.find { |r| r["date"] == "2026-04-01" }
    expect(row["sleep_hours"]).to eq(4.5)
  end

  it "aggregates water_ml as sum for the day" do
    client.water_intakes.create!(amount_ml: 300, recorded_at: Time.zone.parse("2026-04-02 09:00"))
    client.water_intakes.create!(amount_ml: 500, recorded_at: Time.zone.parse("2026-04-02 14:00"))

    get_aggregates(client_id: client.id,
                   headers: auth_headers_for(practitioner))

    row = response_data.find { |r| r["date"] == "2026-04-02" }
    expect(row["water_ml"]).to eq(800)
  end

  it "aggregates symptom_count as count for the day" do
    2.times do
      client.symptoms.create!(
        name: "Headache",
        occurred_at: Time.zone.parse("2026-04-03 10:00")
      )
    end

    get_aggregates(client_id: client.id,
                   headers: auth_headers_for(practitioner))

    row = response_data.find { |r| r["date"] == "2026-04-03" }
    expect(row["symptom_count"]).to eq(2)
  end

  it "handles timezone: UTC log appears on different date in a UTC+9 timezone" do
    # 2026-04-01 23:00 UTC = 2026-04-02 08:00 Asia/Tokyo
    client.energy_logs.create!(
      level: 7,
      recorded_at: Time.utc(2026, 4, 1, 23, 0, 0)
    )

    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "2026-04-01", to: "2026-04-03", tz: "UTC" },
      headers: auth_headers_for(practitioner)

    utc_row = response_data.find { |r| r["date"] == "2026-04-01" }
    expect(utc_row["energy_level"]).to eq(7.0)

    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "2026-04-01", to: "2026-04-03", tz: "Asia/Tokyo" },
      headers: auth_headers_for(practitioner)

    tokyo_apr1 = response_data.find { |r| r["date"] == "2026-04-01" }
    tokyo_apr2 = response_data.find { |r| r["date"] == "2026-04-02" }
    expect(tokyo_apr1["energy_level"]).to be_nil
    expect(tokyo_apr2["energy_level"]).to eq(7.0)
  end

  it "filters to only requested metrics but always returns all keys" do
    client.energy_logs.create!(level: 5, recorded_at: Time.zone.parse("2026-04-01 10:00"))

    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "2026-04-01", to: "2026-04-01", metrics: "energy,sleep" },
      headers: auth_headers_for(practitioner)

    row = response_data.first
    expect(row["energy_level"]).to eq(5.0)
    expect(row).to have_key("sleep_hours")
    expect(row).to have_key("symptom_count")
    expect(row["symptom_count"]).to be_nil
  end

  it "falls back to UTC for an unrecognised timezone" do
    client.energy_logs.create!(
      level: 7,
      recorded_at: Time.utc(2026, 4, 1, 23, 0, 0)
    )

    get "/api/v1/clients/#{client.id}/daily_aggregates",
      params: { from: "2026-04-01", to: "2026-04-03", tz: "Not/AZone" },
      headers: auth_headers_for(practitioner)

    row = response_data.find { |r| r["date"] == "2026-04-01" }
    expect(row["energy_level"]).to eq(7.0)
  end
end
