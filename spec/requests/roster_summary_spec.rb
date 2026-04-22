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

  describe "adherence_days" do
    it "is 0 when the client has never logged anything" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner)

      get_roster(practitioner: practitioner)

      expect(response_data.first["adherence_days"]).to eq(0)
    end

    it "counts distinct days with any entry across all six entry types" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      day = Time.current.beginning_of_day
      # Two energy logs on same day — counts as 1 day
      client.energy_logs.create!(level: 7, recorded_at: day)
      client.energy_logs.create!(level: 8, recorded_at: day + 1.hour)
      # One sleep log on a different day
      client.sleep_logs.create!(hours_slept: 7, bedtime: day - 1.day, wake_time: day - 1.day + 7.hours)
      # One symptom, water, food, supplement each on yet another day
      client.symptoms.create!(name: "Headache", occurred_at: day - 2.days)
      client.water_intakes.create!(amount_ml: 500, recorded_at: day - 3.days)
      client.food_entries.create!(consumed_at: day - 4.days, meal_type: "lunch", description: "Salad")
      client.supplements.create!(name: "Vitamin D", taken_at: day - 5.days)

      get_roster(practitioner: practitioner)

      expect(response_data.first["adherence_days"]).to eq(6)
    end

    it "does not count entries older than 30 days" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      client.energy_logs.create!(level: 7, recorded_at: 31.days.ago)

      get_roster(practitioner: practitioner)

      expect(response_data.first["adherence_days"]).to eq(0)
    end
  end

  describe "last_logged_days_ago" do
    it "is null when the client has never logged anything" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner)

      get_roster(practitioner: practitioner)

      expect(response_data.first["last_logged_days_ago"]).to be_nil
    end

    it "is 0 when the most recent entry was today" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      client.energy_logs.create!(level: 7, recorded_at: Time.current)

      get_roster(practitioner: practitioner)

      expect(response_data.first["last_logged_days_ago"]).to eq(0)
    end

    it "is the correct integer days since the most recent entry across all types" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Most recent entry: 3 days ago (a supplement)
      client.supplements.create!(name: "Zinc", taken_at: 3.days.ago)
      # Older entry: 10 days ago (energy log) — should not affect result
      client.energy_logs.create!(level: 5, recorded_at: 10.days.ago)

      get_roster(practitioner: practitioner)

      expect(response_data.first["last_logged_days_ago"]).to eq(3)
    end
  end

  describe "next_appointment" do
    def create_appointment(client:, practitioner:, **attrs)
      client.appointments.create!({
        practitioner:     practitioner,
        scheduled_at:     1.week.from_now,
        duration_minutes: 60,
        appointment_type: "follow_up",
        status:           "scheduled"
      }.merge(attrs))
    end

    it "is null when the client has no upcoming scheduled appointment" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner)

      get_roster(practitioner: practitioner)

      expect(response_data.first["next_appointment"]).to be_nil
    end

    it "is null for past appointments" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      create_appointment(client: client, practitioner: practitioner,
                         scheduled_at: 1.day.ago)

      get_roster(practitioner: practitioner)

      expect(response_data.first["next_appointment"]).to be_nil
    end

    it "is null for cancelled appointments" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      create_appointment(client: client, practitioner: practitioner,
                         status: "cancelled")

      get_roster(practitioner: practitioner)

      expect(response_data.first["next_appointment"]).to be_nil
    end

    it "returns the earliest scheduled upcoming appointment" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      create_appointment(client: client, practitioner: practitioner,
                         scheduled_at: 2.weeks.from_now, appointment_type: "check_in")
      first = create_appointment(client: client, practitioner: practitioner,
                                 scheduled_at: 3.days.from_now, appointment_type: "labs_review",
                                 duration_minutes: 45)

      get_roster(practitioner: practitioner)

      appt = response_data.first["next_appointment"]
      expect(appt["id"]).to eq(first.id)
      expect(appt["id"]).to be_an(Integer)
      expect(appt["appointment_type"]).to eq("labs_review")
      expect(appt["duration_minutes"]).to eq(45)
      expect(appt["scheduled_at"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
    end

    it "returns only the four specified fields" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      create_appointment(client: client, practitioner: practitioner)

      get_roster(practitioner: practitioner)

      appt = response_data.first["next_appointment"]
      expect(appt.keys).to match_array(%w[id scheduled_at appointment_type duration_minutes])
    end
  end
end
