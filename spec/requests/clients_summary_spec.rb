require "rails_helper"

RSpec.describe "Clients summary", type: :request do
  def get_roster(practitioner:, **params)
    get "/api/v1/clients/summary",
      params: params,
      headers: auth_headers_for(practitioner)
  end

  it "requires practitioner authentication" do
    get "/api/v1/clients/summary"
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
    expect(response_data.map { |r| r["client_id"] }).to eq([ own_client.id ])
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

  describe "tz param" do
    it "assigns energy log to today's slot when tz shifts the timestamp to today" do
      travel_to Time.utc(2026, 4, 14, 15, 0, 0) do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # 2026-04-14 15:00 UTC = 2026-04-15 01:00 AEST — today in AEST, yesterday in UTC
        client.energy_logs.create!(level: 7.0, recorded_at: Time.utc(2026, 4, 14, 15, 0, 0))

        get_roster(practitioner: practitioner, tz: "Australia/Sydney")

        sparkline = response_data.first["energy_sparkline"]
        expect(sparkline.last).to eq(7.0)   # index 29 = today in AEST
        expect(sparkline[-2]).to be_nil     # index 28 = yesterday in AEST (no data)
      end
    end

    it "counts an entry as today for adherence when tz shifts the timestamp to today" do
      travel_to Time.utc(2026, 4, 14, 15, 0, 0) do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Same entry as above: UTC yesterday, AEST today
        client.energy_logs.create!(level: 5.0, recorded_at: Time.utc(2026, 4, 14, 15, 0, 0))

        get_roster(practitioner: practitioner, tz: "Australia/Sydney")

        expect(response_data.first["adherence_days"]).to eq(1)
      end
    end

    it "returns last_logged_days_ago: 0 when tz shifts the most recent entry to today" do
      travel_to Time.utc(2026, 4, 14, 15, 0, 0) do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Same entry: UTC yesterday, AEST today
        client.energy_logs.create!(level: 5.0, recorded_at: Time.utc(2026, 4, 14, 15, 0, 0))

        get_roster(practitioner: practitioner, tz: "Australia/Sydney")

        expect(response_data.first["last_logged_days_ago"]).to eq(0)
      end
    end

    it "falls back to UTC for an unrecognised tz param" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner, accepted: true)

      get_roster(practitioner: practitioner, tz: "Not/ATimezone")

      expect(response.status).to eq(200)
      summary = response_data.first
      expect(summary).to have_key("energy_sparkline")
      expect(summary["energy_sparkline"].length).to eq(30)
    end
  end

  describe "flags" do
    it "includes 'new' for a client who has not accepted their invite" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner, accepted: false)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).to include("new")
    end

    it "does not include 'new' for a client who has accepted their invite" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner, accepted: true)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("new")
    end

    it "includes 'gap' when the client has not logged in 3 or more days and is not pending" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner, accepted: true)
      client.energy_logs.create!(level: 5, recorded_at: 4.days.ago)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).to include("gap")
    end

    it "does not include 'gap' when the client logged 2 days ago" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      client.energy_logs.create!(level: 5, recorded_at: 2.days.ago)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("gap")
    end

    it "includes 'gap' when the client last logged exactly 3 days ago" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner, accepted: true)
      client.energy_logs.create!(level: 5, recorded_at: 3.days.ago)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).to include("gap")
    end

    it "does not include 'gap' for a pending client even if they have never logged" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner, accepted: false)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("gap")
    end

    it "does not include 'gap' when the client has never logged and is accepted" do
      practitioner = create_practitioner
      create_client(practitioner: practitioner, accepted: true)

      get_roster(practitioner: practitioner)

      # last_logged_days_ago is nil — gap only fires when there IS a known last log >= 3 days ago
      expect(response_data.first["flags"]).not_to include("gap")
    end

    describe "'sleep-down' flag" do
      it "includes 'sleep-down' when last 7 days avg hours_slept < prior 7 days avg - 0.5" do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Prior 7 days: avg = 8.0 hours
        client.sleep_logs.create!(hours_slept: 8.0, bedtime: 10.days.ago, wake_time: 10.days.ago + 8.hours)
        # Last 7 days: avg = 6.0 hours (6.0 < 8.0 - 0.5 = 7.5)
        client.sleep_logs.create!(hours_slept: 6.0, bedtime: 3.days.ago, wake_time: 3.days.ago + 6.hours)

        get_roster(practitioner: practitioner)

        expect(response_data.first["flags"]).to include("sleep-down")
      end

      it "excludes 'sleep-down' when last 7 days avg is not sufficiently below prior avg" do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Prior 7 days: avg = 8.0 hours
        client.sleep_logs.create!(hours_slept: 8.0, bedtime: 10.days.ago, wake_time: 10.days.ago + 8.hours)
        # Last 7 days: avg = 7.8 hours (7.8 is not < 8.0 - 0.5 = 7.5)
        client.sleep_logs.create!(hours_slept: 7.8, bedtime: 3.days.ago, wake_time: 3.days.ago + 7.8.hours)

        get_roster(practitioner: practitioner)

        expect(response_data.first["flags"]).not_to include("sleep-down")
      end

      it "excludes 'sleep-down' when either window has no data" do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Only last 7 days has data — prior window is empty
        client.sleep_logs.create!(hours_slept: 5.0, bedtime: 3.days.ago, wake_time: 3.days.ago + 5.hours)

        get_roster(practitioner: practitioner)

        expect(response_data.first["flags"]).not_to include("sleep-down")
      end
    end

    describe "'symptom-up' flag" do
      it "includes 'symptom-up' when last 7 days average > 1.5x prior 7 days average" do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Prior 7 days: 1 symptom on 1 day → avg = 1.0
        client.symptoms.create!(name: "Fatigue", occurred_at: 10.days.ago)
        # Last 7 days: 3 symptoms on 1 day → avg = 3.0 (3.0 > 1.5 * 1.0)
        3.times { client.symptoms.create!(name: "Fatigue", occurred_at: 3.days.ago) }

        get_roster(practitioner: practitioner)

        expect(response_data.first["flags"]).to include("symptom-up")
      end

      it "excludes 'symptom-up' when last 7 days average is not > 1.5x prior" do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Prior 7 days: 2 symptoms on 1 day → avg = 2.0
        2.times { client.symptoms.create!(name: "Fatigue", occurred_at: 10.days.ago) }
        # Last 7 days: 2 symptoms on 1 day → avg = 2.0 (2.0 is not > 1.5 * 2.0 = 3.0)
        2.times { client.symptoms.create!(name: "Fatigue", occurred_at: 3.days.ago) }

        get_roster(practitioner: practitioner)

        expect(response_data.first["flags"]).not_to include("symptom-up")
      end

      it "excludes 'symptom-up' when either window has no data" do
        practitioner = create_practitioner
        client       = create_client(practitioner: practitioner, accepted: true)
        # Only last 7 days has data — prior window is empty
        3.times { client.symptoms.create!(name: "Fatigue", occurred_at: 3.days.ago) }

        get_roster(practitioner: practitioner)

        expect(response_data.first["flags"]).not_to include("symptom-up")
      end
    end
  end
end
