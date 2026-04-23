# Roster Summary Endpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `GET /api/v1/clients/summary` — a single-response, no-N+1 endpoint that returns per-client sparklines, adherence, flags, and next appointments for the practitioner dashboard.

**Architecture:** A `ClientsSummaryService` issues five bulk SQL queries (each across all client IDs simultaneously), then merges results in Ruby. The controller action is a collection action on the existing `clients` resource. No new migrations required — all data is in existing tables.

**Tech Stack:** Rails 7.2, PostgreSQL (uses `DISTINCT ON`, `DATE(... AT TIME ZONE ...)`, `UNION ALL`), RSpec request specs.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `config/routes.rb` | Modify | Add `get :summary, on: :collection` |
| `app/controllers/api/v1/clients_controller.rb` | Modify | Add `summary` action |
| `app/services/summary_service.rb` | Create | All five bulk queries + merge logic |
| `spec/requests/summary_spec.rb` | Create | Full request spec coverage |

---

## Task 1: Route + auth + scaffold

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/clients_controller.rb`
- Create: `spec/requests/summary_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/summary_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Roster summary", type: :request do
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
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all 4 examples fail (routing error — route doesn't exist yet).

- [ ] **Step 3: Add route**

In `config/routes.rb`, change the clients resource block from:

```ruby
resources :clients, only: [ :index, :show, :create, :update, :destroy ] do
  post :resend_invite, on: :member
end
```

to:

```ruby
resources :clients, only: [ :index, :show, :create, :update, :destroy ] do
  get  :summary, on: :collection
  post :resend_invite, on: :member
end
```

- [ ] **Step 4: Add stub controller action**

In `app/controllers/api/v1/clients_controller.rb`, add after the `destroy` action (before `resend_invite`):

```ruby
def summary
  render json: { data: [] }
end
```

- [ ] **Step 5: Run spec to see which tests now pass**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: auth test passes, empty-array test passes, shape test fails (returns `[]` instead of one record).

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/clients_controller.rb spec/requests/summary_spec.rb
git commit -m "Add GET /clients/summary route and stub action"
```

---

## Task 2: Service skeleton + energy sparkline

**Files:**
- Create: `app/services/summary_service.rb`
- Modify: `app/controllers/api/v1/clients_controller.rb` (wire service)
- Modify: `spec/requests/summary_spec.rb` (add sparkline tests)

- [ ] **Step 1: Add sparkline tests to the spec**

Add these examples to `spec/requests/summary_spec.rb` (after the existing examples, still inside the `describe` block):

```ruby
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
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "energy_sparkline" --format documentation
```

Expected: all sparkline examples fail (service not wired yet; stub returns `[]`).

- [ ] **Step 3: Create the service**

Create `app/services/summary_service.rb`:

```ruby
class ClientsSummaryService
  def initialize(practitioner, tz_name: "UTC")
    @practitioner = practitioner
    @tz    = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone["UTC"]
    @tz_pg = @tz.tzinfo.name
    @today = Time.current.in_time_zone(@tz).to_date
  end

  def call
    clients = @practitioner.clients.order(:last_name, :first_name)
    return [] if clients.empty?

    ids = clients.map(&:id)

    sparklines = fetch_sparklines(ids)

    clients.map do |client|
      {
        client_id:            client.id,
        energy_sparkline:     sparklines.fetch(client.id, Array.new(30)),
        adherence_days:       0,
        last_logged_days_ago: nil,
        next_appointment:     nil,
        flags:                []
      }
    end
  end

  private

  def window_start
    @window_start ||= @tz.local(@today.year, @today.month, @today.day) - 29.days
  end

  def tz_day(col)
    "DATE((#{col} AT TIME ZONE 'UTC') AT TIME ZONE '#{@tz_pg}')"
  end

  def fetch_sparklines(ids)
    days = (0..29).map { |i| @today - (29 - i) }  # index 0 = today-29, index 29 = today

    day_expr = tz_day("recorded_at")
    rows = EnergyLog
      .where(client_id: ids)
      .where("recorded_at >= ?", window_start)
      .group("client_id", day_expr)
      .average(:level)
    # rows: { [client_id, "YYYY-MM-DD"] => BigDecimal, ... }

    by_client = Hash.new { |h, k| h[k] = {} }
    rows.each do |(cid, day_str), avg|
      by_client[cid][Date.parse(day_str)] = avg.to_f.round(2)
    end

    ids.each_with_object({}) do |id, h|
      day_map = by_client[id]
      h[id]   = days.map { |d| day_map[d] }
    end
  end
end
```

- [ ] **Step 4: Wire service into controller**

Replace the stub `summary` action in `app/controllers/api/v1/clients_controller.rb`:

```ruby
def summary
  tz_name = params.fetch(:tz, "UTC")
  data = ClientsSummaryService.new(@current_practitioner, tz_name: tz_name).call
  render json: { data: data }
end
```

- [ ] **Step 5: Run the full spec to confirm sparkline tests pass**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: auth, empty array, isolation, shape, and all sparkline tests pass. The stub-only other fields (`adherence_days: 0`, `flags: []`, etc.) satisfy the shape test.

- [ ] **Step 6: Commit**

```bash
git add app/services/summary_service.rb app/controllers/api/v1/clients_controller.rb spec/requests/summary_spec.rb
git commit -m "Add ClientsSummaryService with energy sparkline query"
```

---

## Task 3: Adherence days + last_logged_days_ago

**Files:**
- Modify: `app/services/summary_service.rb`
- Modify: `spec/requests/summary_spec.rb`

- [ ] **Step 1: Add adherence and last_logged tests**

Add to `spec/requests/summary_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "adherence_days" -e "last_logged_days_ago" --format documentation
```

Expected: all adherence and last_logged examples fail.

- [ ] **Step 3: Add `fetch_adherence` to the service and wire it into `call`**

Add the following private method to `ClientsSummaryService` (after `fetch_sparklines`):

```ruby
  def fetch_adherence(ids)
    id_in        = ids.map(&:to_i).join(", ")
    quoted_start = ActiveRecord::Base.connection.quote(window_start)
    sql = <<~SQL
      SELECT client_id,
             COUNT(DISTINCT CASE
               WHEN ts >= #{quoted_start}
               THEN #{tz_day('ts')}
             END)::integer AS adherence_days,
             MAX(ts) AS last_logged_at
      FROM (
        SELECT client_id, recorded_at AS ts FROM energy_logs   WHERE client_id IN (#{id_in})
        UNION ALL
        SELECT client_id, bedtime     AS ts FROM sleep_logs    WHERE client_id IN (#{id_in})
        UNION ALL
        SELECT client_id, occurred_at AS ts FROM symptoms      WHERE client_id IN (#{id_in})
        UNION ALL
        SELECT client_id, recorded_at AS ts FROM water_intakes WHERE client_id IN (#{id_in})
        UNION ALL
        SELECT client_id, consumed_at AS ts FROM food_entries  WHERE client_id IN (#{id_in})
        UNION ALL
        SELECT client_id, taken_at    AS ts FROM supplements   WHERE client_id IN (#{id_in})
      ) all_entries
      GROUP BY client_id
    SQL

    ActiveRecord::Base.connection.exec_query(sql).each_with_object({}) do |r, h|
      ts = r["last_logged_at"]
      last_logged_at = ts ? (ts.respond_to?(:utc) ? ts : Time.parse(ts.to_s)) : nil
      h[r["client_id"]] = {
        adherence_days: r["adherence_days"].to_i,
        last_logged_at: last_logged_at
      }
    end
  end
```

Update the `call` method to use `fetch_adherence` and compute `last_logged_days_ago`:

```ruby
  def call
    clients = @practitioner.clients.order(:last_name, :first_name)
    return [] if clients.empty?

    ids = clients.map(&:id)

    sparklines = fetch_sparklines(ids)
    adherence  = fetch_adherence(ids)

    clients.map do |client|
      id  = client.id
      adh = adherence[id] || {}
      last_logged_at   = adh[:last_logged_at]
      last_logged_days_ago = last_logged_at ? (@today - last_logged_at.in_time_zone(@tz).to_date).to_i : nil

      {
        client_id:            id,
        energy_sparkline:     sparklines.fetch(id, Array.new(30)),
        adherence_days:       adh[:adherence_days] || 0,
        last_logged_days_ago: last_logged_days_ago,
        next_appointment:     nil,
        flags:                []
      }
    end
  end
```

- [ ] **Step 4: Run spec**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all previously passing tests still pass; all new adherence and last_logged tests now pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/summary_service.rb spec/requests/summary_spec.rb
git commit -m "Add adherence_days and last_logged_days_ago to roster summary"
```

---

## Task 4: Next appointment

**Files:**
- Modify: `app/services/summary_service.rb`
- Modify: `spec/requests/summary_spec.rb`

- [ ] **Step 1: Add next_appointment tests**

Add to `spec/requests/summary_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "next_appointment" --format documentation
```

Expected: "is null" tests pass (stub returns nil), but "earliest" and "four fields" tests fail.

- [ ] **Step 3: Add `fetch_next_appointments` to the service**

Add after `fetch_adherence`:

```ruby
  def fetch_next_appointments(ids)
    id_in = ids.map(&:to_i).join(", ")
    sql = <<~SQL
      SELECT DISTINCT ON (client_id)
        client_id, id, scheduled_at, appointment_type, duration_minutes
      FROM appointments
      WHERE client_id IN (#{id_in})
        AND status = 'scheduled'
        AND scheduled_at > NOW()
      ORDER BY client_id, scheduled_at ASC
    SQL

    ActiveRecord::Base.connection.exec_query(sql).each_with_object({}) do |r, h|
      ts = r["scheduled_at"]
      scheduled_at = ts.respond_to?(:utc) ? ts.utc : Time.parse(ts.to_s).utc
      h[r["client_id"]] = {
        "id"               => r["id"],
        "scheduled_at"     => scheduled_at.iso8601,
        "appointment_type" => r["appointment_type"],
        "duration_minutes" => r["duration_minutes"].to_i
      }
    end
  end
```

Update `call` to use `fetch_next_appointments` and change `next_appointment: nil` to:

```ruby
    ids = clients.map(&:id)

    sparklines  = fetch_sparklines(ids)
    adherence   = fetch_adherence(ids)
    next_appts  = fetch_next_appointments(ids)

    clients.map do |client|
      id  = client.id
      adh = adherence[id] || {}
      last_logged_at       = adh[:last_logged_at]
      last_logged_days_ago = last_logged_at ? (@today - last_logged_at.in_time_zone(@tz).to_date).to_i : nil

      {
        client_id:            id,
        energy_sparkline:     sparklines.fetch(id, Array.new(30)),
        adherence_days:       adh[:adherence_days] || 0,
        last_logged_days_ago: last_logged_days_ago,
        next_appointment:     next_appts[id],
        flags:                []
      }
    end
```

- [ ] **Step 4: Run spec**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/summary_service.rb spec/requests/summary_spec.rb
git commit -m "Add next_appointment to roster summary using DISTINCT ON"
```

---

## Task 5: Flags — `"new"` and `"gap"`

These flags require no new SQL query — they derive from data already fetched.

**Files:**
- Modify: `app/services/summary_service.rb`
- Modify: `spec/requests/summary_spec.rb`

- [ ] **Step 1: Add flag tests**

Add to `spec/requests/summary_spec.rb`:

```ruby
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
  end
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "flags" --format documentation
```

Expected: `"new"` and `"gap"` tests fail (flags is always `[]`).

- [ ] **Step 3: Add flag computation to `call`**

Update the `call` method's per-client block to compute flags. Replace the `flags: []` line with:

```ruby
      pending = client.invite_accepted_at.nil?

      flags = []
      flags << "new" if pending
      flags << "gap" if !pending && last_logged_days_ago && last_logged_days_ago >= 3

      {
        client_id:            id,
        energy_sparkline:     sparklines.fetch(id, Array.new(30)),
        adherence_days:       adh[:adherence_days] || 0,
        last_logged_days_ago: last_logged_days_ago,
        next_appointment:     next_appts[id],
        flags:                flags
      }
```

The full updated `call` method is now:

```ruby
  def call
    clients = @practitioner.clients.order(:last_name, :first_name)
    return [] if clients.empty?

    ids = clients.map(&:id)

    sparklines = fetch_sparklines(ids)
    adherence  = fetch_adherence(ids)
    next_appts = fetch_next_appointments(ids)

    clients.map do |client|
      id  = client.id
      adh = adherence[id] || {}
      last_logged_at       = adh[:last_logged_at]
      last_logged_days_ago = last_logged_at ? (@today - last_logged_at.in_time_zone(@tz).to_date).to_i : nil
      pending              = client.invite_accepted_at.nil?

      flags = []
      flags << "new" if pending
      flags << "gap" if !pending && last_logged_days_ago && last_logged_days_ago >= 3

      {
        client_id:            id,
        energy_sparkline:     sparklines.fetch(id, Array.new(30)),
        adherence_days:       adh[:adherence_days] || 0,
        last_logged_days_ago: last_logged_days_ago,
        next_appointment:     next_appts[id],
        flags:                flags
      }
    end
  end
```

- [ ] **Step 4: Run spec**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/summary_service.rb spec/requests/summary_spec.rb
git commit -m "Add 'new' and 'gap' flags to roster summary"
```

---

## Task 6: Flag — `"symptom-up"`

**Files:**
- Modify: `app/services/summary_service.rb`
- Modify: `spec/requests/summary_spec.rb`

- [ ] **Step 1: Add symptom-up tests**

Add to the `"flags"` describe block in `spec/requests/summary_spec.rb`:

```ruby
    it "includes 'symptom-up' when last 7-day average > 1.5x prior 7-day average" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Prior 7 days (days 7-13 ago): 2 symptoms per day for 3 days = avg 2.0
      3.times { |i| client.symptoms.create!(name: "Nausea", occurred_at: (8 + i).days.ago) }
      3.times { |i| client.symptoms.create!(name: "Nausea", occurred_at: (8 + i).days.ago + 1.hour) }
      # Last 7 days (days 0-6): 5 symptoms today = avg 5.0 (5.0 > 2.0 * 1.5)
      5.times { client.symptoms.create!(name: "Headache", occurred_at: Time.current) }

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).to include("symptom-up")
    end

    it "does not include 'symptom-up' when the increase is not large enough" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Prior avg: 4.0 — last avg: 5.0 (5.0 is NOT > 4.0 * 1.5 = 6.0)
      4.times { client.symptoms.create!(name: "Nausea", occurred_at: 8.days.ago) }
      5.times { client.symptoms.create!(name: "Headache", occurred_at: Time.current) }

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("symptom-up")
    end

    it "does not include 'symptom-up' when only one window has data" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Data only in last 7 days — no prior 7-day data
      5.times { client.symptoms.create!(name: "Headache", occurred_at: Time.current) }

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("symptom-up")
    end
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "symptom-up" --format documentation
```

Expected: all three symptom-up tests fail.

- [ ] **Step 3: Add `fetch_symptom_windows` and `symptom_up?` to the service**

Add after `fetch_next_appointments`:

```ruby
  def two_weeks_start
    @two_weeks_start ||= @tz.local(@today.year, @today.month, @today.day) - 13.days
  end

  def week1_start_date
    @week1_start_date ||= @today - 6
  end

  def fetch_symptom_windows(ids)
    id_in              = ids.map(&:to_i).join(", ")
    quoted_two_weeks   = ActiveRecord::Base.connection.quote(two_weeks_start)
    quoted_week1       = ActiveRecord::Base.connection.quote(week1_start_date.to_s)
    sql = <<~SQL
      SELECT client_id,
             AVG(CASE WHEN day >= #{quoted_week1} THEN daily_count END)::float AS last7_avg,
             AVG(CASE WHEN day <  #{quoted_week1} THEN daily_count END)::float AS prior7_avg
      FROM (
        SELECT client_id,
               #{tz_day('occurred_at')} AS day,
               COUNT(*)::float AS daily_count
        FROM symptoms
        WHERE client_id IN (#{id_in})
          AND occurred_at >= #{quoted_two_weeks}
        GROUP BY client_id, day
      ) daily
      GROUP BY client_id
    SQL

    ActiveRecord::Base.connection.exec_query(sql).each_with_object({}) do |r, h|
      h[r["client_id"]] = { last7: r["last7_avg"]&.to_f, prior7: r["prior7_avg"]&.to_f }
    end
  end

  def symptom_up?(wins)
    return false unless wins
    l, p = wins[:last7], wins[:prior7]
    l && p && l > p * 1.5
  end
```

Update `call` to call `fetch_symptom_windows` and add the flag:

```ruby
  def call
    clients = @practitioner.clients.order(:last_name, :first_name)
    return [] if clients.empty?

    ids = clients.map(&:id)

    sparklines    = fetch_sparklines(ids)
    adherence     = fetch_adherence(ids)
    next_appts    = fetch_next_appointments(ids)
    symptom_wins  = fetch_symptom_windows(ids)

    clients.map do |client|
      id  = client.id
      adh = adherence[id] || {}
      last_logged_at       = adh[:last_logged_at]
      last_logged_days_ago = last_logged_at ? (@today - last_logged_at.in_time_zone(@tz).to_date).to_i : nil
      pending              = client.invite_accepted_at.nil?

      flags = []
      flags << "new"        if pending
      flags << "gap"        if !pending && last_logged_days_ago && last_logged_days_ago >= 3
      flags << "symptom-up" if symptom_up?(symptom_wins[id])

      {
        client_id:            id,
        energy_sparkline:     sparklines.fetch(id, Array.new(30)),
        adherence_days:       adh[:adherence_days] || 0,
        last_logged_days_ago: last_logged_days_ago,
        next_appointment:     next_appts[id],
        flags:                flags
      }
    end
  end
```

- [ ] **Step 4: Run spec**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/summary_service.rb spec/requests/summary_spec.rb
git commit -m "Add symptom-up flag to roster summary"
```

---

## Task 7: Flag — `"sleep-down"`

**Files:**
- Modify: `app/services/summary_service.rb`
- Modify: `spec/requests/summary_spec.rb`

- [ ] **Step 1: Add sleep-down tests**

Add to the `"flags"` describe block:

```ruby
    it "includes 'sleep-down' when last 7-day avg sleep < prior 7-day avg minus 0.5" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Prior 7 days (days 7-13): avg 8.0h sleep
      3.times do |i|
        client.sleep_logs.create!(
          hours_slept: 8.0,
          bedtime:     (8 + i).days.ago,
          wake_time:   (8 + i).days.ago + 8.hours
        )
      end
      # Last 7 days: avg 7.0h (7.0 < 8.0 - 0.5 = 7.5 → fires)
      3.times do |i|
        client.sleep_logs.create!(
          hours_slept: 7.0,
          bedtime:     (1 + i).days.ago,
          wake_time:   (1 + i).days.ago + 7.hours
        )
      end

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).to include("sleep-down")
    end

    it "does not include 'sleep-down' when the drop is less than 0.5h" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Prior avg: 8.0h — last avg: 7.6h (7.6 > 8.0 - 0.5 = 7.5 → does not fire)
      3.times do |i|
        client.sleep_logs.create!(hours_slept: 8.0, bedtime: (8 + i).days.ago,
                                  wake_time: (8 + i).days.ago + 8.hours)
      end
      3.times do |i|
        client.sleep_logs.create!(hours_slept: 7.6, bedtime: (1 + i).days.ago,
                                  wake_time: (1 + i).days.ago + 7.6.hours)
      end

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("sleep-down")
    end

    it "does not include 'sleep-down' when only one window has data" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # Only last 7 days — no prior 7-day data
      client.sleep_logs.create!(hours_slept: 5.0, bedtime: 1.day.ago, wake_time: 1.day.ago + 5.hours)

      get_roster(practitioner: practitioner)

      expect(response_data.first["flags"]).not_to include("sleep-down")
    end
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "sleep-down" --format documentation
```

Expected: all three sleep-down tests fail.

- [ ] **Step 3: Add `fetch_sleep_windows` and `sleep_down?` to the service**

Add after `fetch_symptom_windows`:

```ruby
  def fetch_sleep_windows(ids)
    id_in            = ids.map(&:to_i).join(", ")
    quoted_two_weeks = ActiveRecord::Base.connection.quote(two_weeks_start)
    quoted_week1     = ActiveRecord::Base.connection.quote(week1_start_date.to_s)
    sql = <<~SQL
      SELECT client_id,
             AVG(CASE WHEN day >= #{quoted_week1} THEN avg_hours END)::float AS last7_avg,
             AVG(CASE WHEN day <  #{quoted_week1} THEN avg_hours END)::float AS prior7_avg
      FROM (
        SELECT client_id,
               #{tz_day('bedtime')} AS day,
               AVG(hours_slept)::float AS avg_hours
        FROM sleep_logs
        WHERE client_id IN (#{id_in})
          AND bedtime >= #{quoted_two_weeks}
        GROUP BY client_id, day
      ) daily
      GROUP BY client_id
    SQL

    ActiveRecord::Base.connection.exec_query(sql).each_with_object({}) do |r, h|
      h[r["client_id"]] = { last7: r["last7_avg"]&.to_f, prior7: r["prior7_avg"]&.to_f }
    end
  end

  def sleep_down?(wins)
    return false unless wins
    l, p = wins[:last7], wins[:prior7]
    l && p && l < p - 0.5
  end
```

Update `call` to call `fetch_sleep_windows` and add the flag:

```ruby
  def call
    clients = @practitioner.clients.order(:last_name, :first_name)
    return [] if clients.empty?

    ids = clients.map(&:id)

    sparklines   = fetch_sparklines(ids)
    adherence    = fetch_adherence(ids)
    next_appts   = fetch_next_appointments(ids)
    symptom_wins = fetch_symptom_windows(ids)
    sleep_wins   = fetch_sleep_windows(ids)

    clients.map do |client|
      id  = client.id
      adh = adherence[id] || {}
      last_logged_at       = adh[:last_logged_at]
      last_logged_days_ago = last_logged_at ? (@today - last_logged_at.in_time_zone(@tz).to_date).to_i : nil
      pending              = client.invite_accepted_at.nil?

      flags = []
      flags << "new"         if pending
      flags << "gap"         if !pending && last_logged_days_ago && last_logged_days_ago >= 3
      flags << "symptom-up"  if symptom_up?(symptom_wins[id])
      flags << "sleep-down"  if sleep_down?(sleep_wins[id])

      {
        client_id:            id,
        energy_sparkline:     sparklines.fetch(id, Array.new(30)),
        adherence_days:       adh[:adherence_days] || 0,
        last_logged_days_ago: last_logged_days_ago,
        next_appointment:     next_appts[id],
        flags:                flags
      }
    end
  end
```

- [ ] **Step 4: Run spec**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/summary_service.rb spec/requests/summary_spec.rb
git commit -m "Add sleep-down flag to roster summary"
```

---

## Task 8: Timezone param

**Files:**
- Modify: `spec/requests/summary_spec.rb`

No service changes needed — the `tz` param is already plumbed through from Task 2.

- [ ] **Step 1: Add timezone tests**

Add to `spec/requests/summary_spec.rb`:

```ruby
  describe "tz param" do
    it "shifts day boundaries so a log near midnight falls on the correct local date" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      # 2026-04-20 23:30 UTC = 2026-04-21 09:30 Australia/Sydney (UTC+10)
      # In UTC this is index 28 (yesterday); in Sydney it is index 29 (today)
      log_time = Time.utc(2026, 4, 20, 23, 30, 0)
      travel_to(Time.utc(2026, 4, 21, 12, 0, 0)) do
        client.energy_logs.create!(level: 9, recorded_at: log_time)

        get_roster(practitioner: practitioner, tz: "UTC")
        utc_sparkline = response_data.first["energy_sparkline"]
        expect(utc_sparkline[28]).to eq(9.0)   # yesterday in UTC
        expect(utc_sparkline[29]).to be_nil     # today in UTC

        get_roster(practitioner: practitioner, tz: "Australia/Sydney")
        syd_sparkline = response_data.first["energy_sparkline"]
        expect(syd_sparkline[29]).to eq(9.0)   # today in Sydney
        expect(syd_sparkline[28]).to be_nil     # yesterday in Sydney
      end
    end

    it "falls back to UTC for an unrecognised tz value" do
      practitioner = create_practitioner
      client       = create_client(practitioner: practitioner)
      client.energy_logs.create!(level: 5, recorded_at: Time.current.beginning_of_day + 1.hour)

      get_roster(practitioner: practitioner, tz: "Not/A/Timezone")

      expect(response).to have_http_status(:ok)
      expect(response_data.first["energy_sparkline"][29]).to eq(5.0)
    end
  end
```

- [ ] **Step 2: Run new tests to confirm they fail or expose issues**

```bash
bundle exec rspec spec/requests/summary_spec.rb -e "tz param" --format documentation
```

Expected: "shifts day boundaries" test fails if day alignment is off; "falls back to UTC" should pass.

- [ ] **Step 3: Run the full suite**

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add spec/requests/summary_spec.rb
git commit -m "Add timezone param tests for roster summary"
```

---

## Self-Review Checklist

After all tasks are complete, run against the spec:

- [ ] `energy_sparkline` — 30 elements, index 0 = today−29, index 29 = today, nulls for missing days ✓
- [ ] `adherence_days` — UNION of all 6 types, 30-day window, distinct days ✓
- [ ] `last_logged_days_ago` — null for never-logged, 0 for today, correct integer otherwise ✓
- [ ] `next_appointment` — DISTINCT ON, earliest scheduled, null when none, 4 fields only ✓
- [ ] `"new"` flag — `invite_accepted_at IS NULL` ✓
- [ ] `"gap"` flag — `last_logged_days_ago >= 3`, not set for pending clients ✓
- [ ] `"symptom-up"` flag — DB aggregation, both windows required ✓
- [ ] `"sleep-down"` flag — DB aggregation, both windows required ✓
- [ ] `tz` param — shifts all day-boundary calculations ✓
- [ ] Auth — practitioner JWT required, own clients only ✓
- [ ] No N+1 — 5 bulk queries regardless of client count ✓
- [ ] No pagination — all clients in one response ✓

Run full suite before marking complete:

```bash
bundle exec rspec spec/requests/summary_spec.rb --format documentation
```
