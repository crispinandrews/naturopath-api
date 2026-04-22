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
    rows.each do |(cid, day), avg|
      day_obj = day.is_a?(Date) ? day : Date.parse(day.to_s)
      by_client[cid][day_obj] = avg.to_f.round(2)
    end

    ids.each_with_object({}) do |id, h|
      day_map = by_client[id]
      h[id]   = days.map { |d| day_map[d] }
    end
  end
end
