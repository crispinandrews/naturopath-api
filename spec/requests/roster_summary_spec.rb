require "rails_helper"

RSpec.describe "Roster summary", type: :request do
  def get_roster(practitioner:, **params)
    get "/api/v1/clients/roster_summary",
      params: params,
      headers: auth_headers_for(practitioner)
  end

  it "requires practitioner authentication" do
    get "/api/v1/clients/roster_summary"
    expect_error_response(status: :unauthorized, code: "unauthorized", message: "Unauthorized")
  end

  it "returns an empty array when the practitioner has no clients" do
    practitioner = create_practitioner
    get_roster(practitioner: practitioner)
    expect(response).to have_http_status(:ok)
    expect(response_data).to eq([])
  end

  it "returns only the authenticated practitioner's own clients" do
    practitioner       = create_practitioner
    other_practitioner = create_practitioner
    own_client         = create_client(practitioner: practitioner)
    create_client(practitioner: other_practitioner)

    get_roster(practitioner: practitioner)

    expect(response).to have_http_status(:ok)
    expect(response_data.map { |r| r["client_id"] }).to eq([own_client.id])
  end

  it "returns the correct per-client response shape" do
    practitioner = create_practitioner
    client       = create_client(practitioner: practitioner)

    get_roster(practitioner: practitioner)

    record = response_data.first
    expect(record["client_id"]).to eq(client.id)
    expect(record["energy_sparkline"]).to be_an(Array).and have_attributes(size: 30)
    expect(record["adherence_days"]).to be_an(Integer)
    expect(record["flags"]).to be_an(Array)
    expect(record.key?("last_logged_days_ago")).to be true
    expect(record.key?("next_appointment")).to be true
  end

  describe "energy_sparkline" do
    it "is a 30-element array with nil for days with no energy log" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner)

      get_roster(practitioner: practitioner)

      sparkline = response_data.first["energy_sparkline"]
      expect(sparkline).to be_an(Array).and have_attributes(size: 30)
      expect(sparkline).to all(be_nil)
    end

    it "puts the average energy level on the correct day index" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # index 29 = today, so a log 5 days ago is at index 24
      client.energy_logs.create!(level: 6, recorded_at: 5.days.ago.beginning_of_day + 2.hours)
      client.energy_logs.create!(level: 8, recorded_at: 5.days.ago.beginning_of_day + 3.hours)

      get_roster(practitioner: practitioner)

      sparkline = response_data.first["energy_sparkline"]
      expect(sparkline[24]).to eq(7.0)  # avg(6, 8) = 7.0
      expect(sparkline[23]).to be_nil   # 6 days ago — no log
      expect(sparkline[25]).to be_nil   # 4 days ago — no log
      expect(sparkline[29]).to be_nil   # today — no log
    end

    it "places a log from today at index 29" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      client.energy_logs.create!(level: 9, recorded_at: Time.current.beginning_of_day + 1.hour)

      get_roster(practitioner: practitioner)

      sparkline = response_data.first["energy_sparkline"]
      expect(sparkline[29]).to eq(9.0)
    end

    it "rounds sparkline values to 2 decimal places" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      client.energy_logs.create!(level: 7, recorded_at: Time.current)
      client.energy_logs.create!(level: 8, recorded_at: Time.current + 1.minute)
      client.energy_logs.create!(level: 9, recorded_at: Time.current + 2.minutes)

      get_roster(practitioner: practitioner)

      sparkline = response_data.first["energy_sparkline"]
      expect(sparkline[29]).to eq(8.0)
    end
  end
end
