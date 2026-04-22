class DailyAggregateService
  METRIC_CONFIG = {
    sleep:       { model: :sleep_logs,    ts: :bedtime,     agg: :avg_hours },
    energy:      { model: :energy_logs,   ts: :recorded_at, agg: :avg_level },
    symptoms:    { model: :symptoms,      ts: :occurred_at, agg: :count },
    water:       { model: :water_intakes, ts: :recorded_at, agg: :sum_ml },
    food:        { model: :food_entries,  ts: :consumed_at, agg: :count },
    supplements: { model: :supplements,   ts: :taken_at,    agg: :count }
  }.freeze

  def initialize(client, from:, to:, tz_name: "UTC", metrics: METRIC_CONFIG.keys)
    @client  = client
    @tz      = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone["UTC"]
    @from_date = coerce_date(from)
    @to_date   = coerce_date(to)
    @from      = @tz.local(@from_date.year, @from_date.month, @from_date.day).beginning_of_day
    @to        = @tz.local(@to_date.year, @to_date.month, @to_date.day).end_of_day
    @metrics = Array(metrics).map(&:to_sym) & METRIC_CONFIG.keys
    @tz_name = @tz.tzinfo.name
  end

  def call
    date_range = (@from_date..@to_date).to_a
    result = date_range.index_with { |_| empty_row }

    @metrics.each { |metric| merge_metric(result, metric) }

    date_range.map { |d| result[d].merge(date: d.iso8601) }
  end

  private

  def empty_row
    { sleep_hours: nil, energy_level: nil, symptom_count: nil,
      water_ml: nil, food_entries: nil, supplement_doses: nil }
  end

  def merge_metric(result, metric)
    cfg   = METRIC_CONFIG[metric]
    scope = @client.public_send(cfg[:model])
                   .where("#{cfg[:ts]} >= ? AND #{cfg[:ts]} <= ?", @from, @to)
    day_expr = "DATE((#{cfg[:ts]} AT TIME ZONE 'UTC') AT TIME ZONE '#{@tz_name}')"

    rows = case cfg[:agg]
    when :avg_hours then scope.group(day_expr).average(:hours_slept)
    when :avg_level then scope.group(day_expr).average(:level)
    when :sum_ml    then scope.group(day_expr).sum(:amount_ml)
    when :count     then scope.group(day_expr).count
    end

    rows.each do |day, value|
      next unless result.key?(day)
      result[day][metric_key(metric)] = value.is_a?(BigDecimal) ? value.to_f.round(2) : value
    end
  end

  def metric_key(metric)
    { sleep: :sleep_hours, energy: :energy_level, symptoms: :symptom_count,
      water: :water_ml, food: :food_entries, supplements: :supplement_doses }[metric]
  end

  def coerce_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  end
end
