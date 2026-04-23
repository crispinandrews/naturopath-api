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
    @client    = client
    @tz        = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone["UTC"]
    @from_date = coerce_date(from)
    @to_date   = coerce_date(to)
    @from      = @tz.local(@from_date.year, @from_date.month, @from_date.day).beginning_of_day
    @to        = @tz.local(@to_date.year, @to_date.month, @to_date.day).end_of_day
    @metrics   = Array(metrics).map(&:to_sym) & METRIC_CONFIG.keys
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
    aggregate_rows_for(metric).each do |day, value|
      next unless result.key?(day)

      result[day][metric_key(metric)] = value
    end
  end

  def metric_key(metric)
    { sleep: :sleep_hours, energy: :energy_level, symptoms: :symptom_count,
      water: :water_ml, food: :food_entries, supplements: :supplement_doses }[metric]
  end

  def aggregate_rows_for(metric)
    case metric
    when :sleep
      average_by_day(@client.sleep_logs.where(bedtime: @from..@to).pluck(:bedtime, :hours_slept))
    when :energy
      average_by_day(@client.energy_logs.where(recorded_at: @from..@to).pluck(:recorded_at, :level))
    when :symptoms
      count_by_day(@client.symptoms.where(occurred_at: @from..@to).pluck(:occurred_at))
    when :water
      sum_by_day(@client.water_intakes.where(recorded_at: @from..@to).pluck(:recorded_at, :amount_ml))
    when :food
      count_by_day(@client.food_entries.where(consumed_at: @from..@to).pluck(:consumed_at))
    when :supplements
      count_by_day(@client.supplements.where(taken_at: @from..@to).pluck(:taken_at))
    else
      {}
    end
  end

  def average_by_day(rows)
    grouped = Hash.new { |h, day| h[day] = [] }

    rows.each do |timestamp, value|
      grouped[local_day(timestamp)] << value.to_f
    end

    grouped.transform_values { |values| (values.sum / values.size).round(2) }
  end

  def count_by_day(timestamps)
    timestamps.each_with_object(Hash.new(0)) do |timestamp, counts|
      counts[local_day(timestamp)] += 1
    end
  end

  def sum_by_day(rows)
    rows.each_with_object(Hash.new(0)) do |(timestamp, value), sums|
      sums[local_day(timestamp)] += value
    end
  end

  def local_day(timestamp)
    timestamp.in_time_zone(@tz).to_date
  end

  def coerce_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  end
end
