class ClientsSummaryService
  TRACKED_SOURCES = [
    [ EnergyLog, :recorded_at ],
    [ SleepLog, :bedtime ],
    [ Symptom, :occurred_at ],
    [ WaterIntake, :recorded_at ],
    [ FoodEntry, :consumed_at ],
    [ Supplement, :taken_at ]
  ].freeze

  def initialize(practitioner, tz_name: "UTC")
    @practitioner = practitioner
    @tz    = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone["UTC"]
    @today = Time.current.in_time_zone(@tz).to_date
  end

  def call
    clients = @practitioner.clients.order(:last_name, :first_name)
    return [] if clients.empty?

    ids = clients.map(&:id)

    sparklines    = fetch_sparklines(ids)
    adherence     = fetch_adherence(ids)
    next_appts    = fetch_next_appointments(ids)
    symptom_wins  = fetch_symptom_windows(ids)
    sleep_wins    = fetch_sleep_windows(ids)

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

  private

  def window_start
    @window_start ||= @tz.local(@today.year, @today.month, @today.day) - 29.days
  end

  def two_weeks_start
    @two_weeks_start ||= @tz.local(@today.year, @today.month, @today.day) - 13.days
  end

  def fetch_sparklines(ids)
    days = (0..29).map { |i| @today - (29 - i) }
    totals_by_client = Hash.new { |h, client_id| h[client_id] = Hash.new { |client_days, day| client_days[day] = [ 0.0, 0 ] } }

    EnergyLog.where(client_id: ids, recorded_at: window_start..)
      .pluck(:client_id, :recorded_at, :level)
      .each do |client_id, recorded_at, level|
        day = recorded_at.in_time_zone(@tz).to_date
        totals = totals_by_client[client_id][day]
        totals[0] += level
        totals[1] += 1
      end

    by_client = Hash.new { |h, client_id| h[client_id] = {} }
    totals_by_client.each do |client_id, day_totals|
      day_totals.each do |day, (sum, count)|
        by_client[client_id][day] = (sum / count).round(2)
      end
    end

    ids.each_with_object({}) do |id, h|
      day_map = by_client[id]
      h[id]   = days.map { |d| day_map[d] }
    end
  end

  def fetch_adherence(ids)
    adherence_days = Hash.new { |h, client_id| h[client_id] = {} }
    last_logged_at = {}

    TRACKED_SOURCES.each do |model, column|
      model.where(client_id: ids).group(:client_id).maximum(column).each do |client_id, timestamp|
        next unless timestamp
        next if last_logged_at[client_id] && last_logged_at[client_id] >= timestamp

        last_logged_at[client_id] = timestamp
      end

      model.where(client_id: ids, column => window_start..).pluck(:client_id, column).each do |client_id, timestamp|
        adherence_days[client_id][timestamp.in_time_zone(@tz).to_date] = true
      end
    end

    ids.each_with_object({}) do |client_id, memo|
      memo[client_id] = {
        adherence_days: adherence_days[client_id].size,
        last_logged_at: last_logged_at[client_id]
      }
    end
  end

  def fetch_next_appointments(ids)
    Appointment.where(client_id: ids, status: "scheduled")
      .where("scheduled_at > ?", Time.current)
      .order(:client_id, :scheduled_at)
      .each_with_object({}) do |appointment, memo|
        next if memo.key?(appointment.client_id)

        memo[appointment.client_id] = {
          "id"               => appointment.id,
          "scheduled_at"     => appointment.scheduled_at.utc.iso8601,
          "appointment_type" => appointment.appointment_type,
          "duration_minutes" => appointment.duration_minutes
        }
      end
  end

  def fetch_symptom_windows(ids)
    counts_by_client = Hash.new { |h, client_id| h[client_id] = Hash.new(0) }

    Symptom.where(client_id: ids, occurred_at: two_weeks_start..).pluck(:client_id, :occurred_at).each do |client_id, occurred_at|
      counts_by_client[client_id][occurred_at.in_time_zone(@tz).to_date] += 1
    end

    build_window_averages(counts_by_client)
  end

  def build_window_averages(values_by_client)
    ids = values_by_client.keys
    week1_start = @today - 6

    ids.each_with_object({}) do |client_id, memo|
      values = values_by_client[client_id]
      last7_values = values.filter_map { |day, value| value if day >= week1_start }
      prior7_values = values.filter_map { |day, value| value if day < week1_start }

      memo[client_id] = {
        last7_avg: average(last7_values),
        prior7_avg: average(prior7_values)
      }
    end
  end

  def symptom_up?(window)
    return false unless window
    last7  = window[:last7_avg]
    prior7 = window[:prior7_avg]
    !last7.nil? && !prior7.nil? && last7 > prior7 * 1.5
  end

  def fetch_sleep_windows(ids)
    hours_by_client = Hash.new { |h, client_id| h[client_id] = Hash.new { |client_days, day| client_days[day] = [] } }

    SleepLog.where(client_id: ids, bedtime: two_weeks_start..).pluck(:client_id, :bedtime, :hours_slept).each do |client_id, bedtime, hours_slept|
      hours_by_client[client_id][bedtime.in_time_zone(@tz).to_date] << hours_slept.to_f
    end

    daily_averages = hours_by_client.transform_values do |day_values|
      day_values.transform_values { |hours| average(hours) }
    end

    build_window_averages(daily_averages)
  end

  def sleep_down?(window)
    return false unless window
    last7  = window[:last7_avg]
    prior7 = window[:prior7_avg]
    !last7.nil? && !prior7.nil? && last7 < prior7 - 0.5
  end

  def average(values)
    return nil if values.empty?

    values.sum.to_f / values.size
  end
end
