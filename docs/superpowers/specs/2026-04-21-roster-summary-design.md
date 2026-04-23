# Roster Summary Endpoint — Design Spec

**Date:** 2026-04-21
**Route:** `GET /api/v1/clients/summary`

---

## Overview

A lightweight, per-client summary endpoint for the practitioner's client list. Feeds a dashboard table showing sparklines, adherence rings, flags, and next appointments. Must return all clients in a single response with no N+1 queries.

---

## Authentication & Authorisation

- Requires practitioner JWT (same `authenticate_practitioner!` before_action as all other `/clients` routes).
- Returns only the authenticated practitioner's own clients.

---

## Query Parameters

| Param | Type   | Default | Description |
|-------|--------|---------|-------------|
| `tz`  | string | `"UTC"` | IANA timezone string (e.g. `"Australia/Sydney"`). Used for day-boundary calculations. Falls back to UTC if unrecognised. |

---

## Response Shape

```json
{
  "data": [
    {
      "client_id": 1,
      "energy_sparkline": [6.2, 5.8, null, 7.1],
      "adherence_days": 24,
      "last_logged_days_ago": 1,
      "next_appointment": {
        "id": 42,
        "scheduled_at": "2026-04-23T10:30:00Z",
        "appointment_type": "labs_review",
        "duration_minutes": 60
      },
      "flags": ["sleep-down"]
    }
  ]
}
```

No pagination. All clients returned in one response (practices are small, typically <50 clients).

---

## Field Definitions

### `energy_sparkline`
- 30-element array. Index 0 = 29 days ago (in the practitioner's timezone), index 29 = today. *(The original spec says "index 0 = 30 days ago" — a 30-element array with today at index 29 means the earliest slot is 29 days ago. Implemented as: window = [today−29 .. today], 30 days inclusive.)*
- Each value: average `energy_logs.level` for that calendar day, rounded to 2 decimal places. `null` if no energy log exists for that day.
- Timezone: use the `tz` param for day boundaries.

### `adherence_days`
- Count of distinct calendar days in the last 30 (today inclusive) where the client logged at least one entry of any type: `sleep_logs`, `energy_logs`, `symptoms`, `water_intakes`, `food_entries`, `supplements`.
- Timezone: use the `tz` param for day boundaries.

### `last_logged_days_ago`
- Integer: number of complete calendar days since the client's most recent entry across all 6 entry types.
- `null` if the client has never logged anything.
- `0` if the most recent entry was today (in the practitioner's timezone).

### `next_appointment`
- The earliest appointment for this client where `status = 'scheduled'` and `scheduled_at > NOW()`.
- Fields returned: `id`, `scheduled_at` (ISO 8601 UTC), `appointment_type`, `duration_minutes`.
- `null` if no such appointment exists.

### `flags`
Array of zero or more strings:

| Flag | Condition |
|------|-----------|
| `"symptom-up"` | Average daily symptom-record count over last 7 days > 1.5× average over prior 7 days (days 8–14 ago). Only set if both windows have at least one day with data. |
| `"sleep-down"` | Average `sleep_logs.hours_slept` over last 7 days < average over prior 7 days minus 0.5. Only set if both windows have at least one day with data. |
| `"gap"` | `last_logged_days_ago >= 3`. Not set for pending clients (`invite_accepted_at IS NULL`). |
| `"new"` | `invite_accepted_at IS NULL`. |

---

## Architecture

### Route

Add a collection action to the existing `clients` resource:

```ruby
resources :clients, only: [:index, :show, :create, :update, :destroy] do
  get :summary, on: :collection
  post :resend_invite, on: :member
end
```

### Controller

New `summary` action in `Api::V1::ClientsController`:

```ruby
def summary
  tz_name = params.fetch(:tz, "UTC")
  data = ClientsSummaryService.new(@current_practitioner, tz_name: tz_name).call
  render json: { data: data }
end
```

No serializer — the service returns plain hashes matching the specified shape exactly.

### Service: `ClientsSummaryService`

Located at `app/services/clients_summary_service.rb`. Initialised with a `Practitioner` and `tz_name`. `#call` returns an array of hashes, one per client.

Issues **5 bulk SQL queries** (each across all client IDs simultaneously, no per-client queries):

#### Query 1 — Energy sparkline
```sql
SELECT client_id,
       DATE((recorded_at AT TIME ZONE 'UTC') AT TIME ZONE :tz) AS day,
       ROUND(AVG(level)::numeric, 2) AS avg_level
FROM energy_logs
WHERE client_id IN (:ids)
  AND recorded_at >= :window_start
GROUP BY client_id, day
```
Window: 30 days back from start-of-today in the given timezone.

Ruby assembles 30-element arrays per client, filling `nil` for missing days.

#### Query 2 — Adherence + last-logged
UNION ALL of all 6 entry tables with no time filter in the subqueries (so `MAX(ts)` captures the all-time last entry). The 30-day window is applied inside the `COUNT DISTINCT` via `CASE WHEN`:

```sql
SELECT client_id,
       COUNT(DISTINCT CASE
         WHEN ts >= :window_start
         THEN DATE((ts AT TIME ZONE 'UTC') AT TIME ZONE :tz)
       END) AS adherence_days,
       MAX(ts) AS last_logged_at
FROM (
  SELECT client_id, recorded_at AS ts FROM energy_logs  WHERE client_id IN (:ids)
  UNION ALL
  SELECT client_id, bedtime     AS ts FROM sleep_logs   WHERE client_id IN (:ids)
  UNION ALL
  SELECT client_id, occurred_at AS ts FROM symptoms     WHERE client_id IN (:ids)
  UNION ALL
  SELECT client_id, recorded_at AS ts FROM water_intakes WHERE client_id IN (:ids)
  UNION ALL
  SELECT client_id, consumed_at AS ts FROM food_entries  WHERE client_id IN (:ids)
  UNION ALL
  SELECT client_id, taken_at    AS ts FROM supplements   WHERE client_id IN (:ids)
) all_entries
GROUP BY client_id
```

`window_start` = start of today (practitioner tz) minus 29 days. `last_logged_at` is unconstrained — captures the all-time most recent entry. Ruby converts to days-ago relative to today in the practitioner's timezone.

#### Query 3 — Symptom windows
```sql
SELECT client_id,
       AVG(CASE WHEN day >= :week1_start THEN daily_count END) AS last7_avg,
       AVG(CASE WHEN day <  :week1_start THEN daily_count END) AS prior7_avg
FROM (
  SELECT client_id,
         DATE((occurred_at AT TIME ZONE 'UTC') AT TIME ZONE :tz) AS day,
         COUNT(*) AS daily_count
  FROM symptoms
  WHERE client_id IN (:ids)
    AND occurred_at >= :two_weeks_start
  GROUP BY client_id, day
) daily
GROUP BY client_id
```
`week1_start` = 7 days ago (start of day, practitioner tz). `two_weeks_start` = 14 days ago.

#### Query 4 — Sleep windows
Same pattern as Query 3 but over `sleep_logs`, averaging `hours_slept` directly (no inner count grouping needed):

```sql
SELECT client_id,
       AVG(CASE WHEN day >= :week1_start THEN avg_hours END) AS last7_avg,
       AVG(CASE WHEN day <  :week1_start THEN avg_hours END) AS prior7_avg
FROM (
  SELECT client_id,
         DATE((bedtime AT TIME ZONE 'UTC') AT TIME ZONE :tz) AS day,
         AVG(hours_slept) AS avg_hours
  FROM sleep_logs
  WHERE client_id IN (:ids)
    AND bedtime >= :two_weeks_start
  GROUP BY client_id, day
) daily
GROUP BY client_id
```

#### Query 5 — Next appointments
```sql
SELECT DISTINCT ON (client_id)
  client_id, id, scheduled_at, appointment_type, duration_minutes
FROM appointments
WHERE client_id IN (:ids)
  AND status = 'scheduled'
  AND scheduled_at > NOW()
ORDER BY client_id, scheduled_at ASC
```

PostgreSQL's `DISTINCT ON` returns the earliest appointment per client in a single scan.

### Merge & Flag Computation (Ruby)

After all 5 queries complete, iterate over clients (ordered by `last_name, first_name` to match the existing `index` action). For each client:

1. Look up sparkline data from Query 1 result map.
2. Look up adherence + last-logged from Query 2.
3. Compute `last_logged_days_ago` from `last_logged_at` relative to today in the practitioner's timezone.
4. Look up next appointment from Query 5.
5. Compute flags:
   - `"new"` — `client.invite_accepted_at.nil?`
   - `"gap"` — `last_logged_days_ago >= 3 && !client.invite_accepted_at.nil?`
   - `"symptom-up"` — from Query 3: `last7_avg.present? && prior7_avg.present? && last7_avg > prior7_avg * 1.5`
   - `"sleep-down"` — from Query 4: `last7_avg.present? && prior7_avg.present? && last7_avg < prior7_avg - 0.5`

---

## Testing

Spec at `spec/requests/clients_summary_spec.rb`. Cover:

- Returns 200 with correct shape for authenticated practitioner.
- Returns 401 for unauthenticated requests.
- `energy_sparkline`: correct 30-element array, `null` for missing days, correct day alignment.
- `adherence_days`: counts across all 6 entry types, not double-counting days.
- `last_logged_days_ago`: `null` for never-logged client; `0` for logged today; correct integer otherwise.
- `next_appointment`: correct earliest scheduled appointment; `null` when none.
- Each flag fires correctly and is absent when condition is not met.
- `"gap"` is absent for pending clients.
- `tz` param shifts day boundaries correctly.
- Only returns the authenticated practitioner's clients (not another practitioner's).

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `config/routes.rb` | Add `get :summary, on: :collection` |
| `app/controllers/api/v1/clients_controller.rb` | Add `summary` action |
| `app/services/clients_summary_service.rb` | New service |
| `spec/requests/clients_summary_spec.rb` | New request spec |
