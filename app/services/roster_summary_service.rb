class RosterSummaryService
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
    rows.each do |(cid, day), avg|
      day_obj = day.is_a?(Date) ? day : Date.parse(day.to_s)
      by_client[cid][day_obj] = avg.to_f.round(2)
    end

    ids.each_with_object({}) do |id, h|
      day_map = by_client[id]
      h[id]   = days.map { |d| day_map[d] }
    end
  end

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
end
