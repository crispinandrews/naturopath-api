# NaturoPath API

REST API backend for the NaturoPath health tracking platform. Built with Rails 7.2 in API mode.

## Overview

NaturoPath is a health data tracking platform for naturopathy practitioners. Clients use native mobile apps (iOS/Android) to log daily health data such as food intake, symptoms, energy levels, sleep, water intake, and supplements. Practitioners access a web dashboard to review client data during consultations.

This API serves all three frontends:

- **naturopath-dashboard** — Next.js web app for the practitioner
- **naturopath-ios** — Swift/SwiftUI iOS app for clients
- **naturopath-android** — Kotlin/Jetpack Compose Android app for clients

## Tech Stack

- Ruby 3.4.5
- Rails 7.2 (API mode)
- PostgreSQL
- JWT authentication
- bcrypt password hashing

## Getting Started

### Prerequisites

- Ruby 3.4.5 (via rbenv)
- PostgreSQL 14+

### Setup

```bash
git clone git@github-personal:crispinandrews/naturopath-api.git
cd naturopath-api
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

The API will be available at `http://localhost:3000`.

### Local Quality Gate

Run the same checks used in CI before pushing:

```bash
bin/ci
```

### Test Credentials (development)

| Role | Email | Password |
|------|-------|----------|
| Practitioner | practitioner@example.com | password123 |
| Client 1 | client1@example.com | password123 |
| Client 2 | client2@example.com | password123 |

## API Endpoints

All endpoints are under `/api/v1/`. The canonical API contract is now maintained in [docs/openapi.yaml](docs/openapi.yaml). Use that OpenAPI spec as the integration source of truth for the dashboard, iOS app, and Android app.

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/practitioner/login` | Practitioner login |
| POST | `/client/login` | Client login |
| POST | `/client/accept_invite` | Accept invite and set password |
| POST | `/client/forgot_password` | Request password reset email |
| POST | `/client/reset_password` | Reset password with token |
| POST | `/client/refresh` | Rotate refresh token and issue a new access token |
| POST | `/client/logout` | Revoke a refresh token |

All authenticated endpoints require a JWT token in the `Authorization: Bearer <token>` header.

Authentication hardening currently includes:

- Invite-only client onboarding
- Invite expiry after 14 days
- Rate limiting on practitioner login, client login, and invite acceptance
- JWT issuer, audience, issued-at, and key ID claims
- Support for one previous JWT signing secret during key rotation
- Client refresh tokens with rotation and logout revocation
- Client password reset tokens delivered by email

### Practitioner Endpoints

Require practitioner authentication.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/clients` | List all clients |
| POST | `/clients` | Create (invite) a new client |
| GET | `/clients/:id` | View client details |
| PATCH | `/clients/:id` | Update client |
| DELETE | `/clients/:id` | Delete client |
| POST | `/clients/:id/resend_invite` | Rotate invite token and extend invite expiry |
| GET | `/clients/:id/food_entries` | View client's food entries |
| GET | `/clients/:id/symptoms` | View client's symptoms |
| GET | `/clients/:id/energy_logs` | View client's energy logs |
| GET | `/clients/:id/sleep_logs` | View client's sleep logs |
| GET | `/clients/:id/water_intakes` | View client's water intake |
| GET | `/clients/:id/supplements` | View client's supplements |

### Client Endpoints

Require client authentication. All data is scoped to the authenticated client.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/client/profile` | View own profile |
| PATCH | `/client/profile` | Update own profile |
| PATCH | `/client/password` | Change own password |
| POST | `/client/sync` | Sync queued offline health-record operations |
| GET/POST/PATCH/DELETE | `/client/food_entries` | Manage food entries |
| GET/POST/PATCH/DELETE | `/client/symptoms` | Manage symptoms |
| GET/POST/PATCH/DELETE | `/client/energy_logs` | Manage energy logs |
| GET/POST/PATCH/DELETE | `/client/sleep_logs` | Manage sleep logs |
| GET/POST/PATCH/DELETE | `/client/water_intakes` | Manage water intake |
| GET/POST/PATCH/DELETE | `/client/supplements` | Manage supplements |
| GET/POST | `/client/consents` | View and grant consents |

### GDPR Endpoints

Require client authentication.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/gdpr/export` | Export all personal data (JSON) |
| DELETE | `/gdpr/delete` | Delete all health data |

### Filtering

All list endpoints support date range filtering via query parameters:

```
GET /api/v1/client/food_entries?from=2026-04-01&to=2026-04-07
```

Date-only filters are interpreted in the app time zone. `from` uses the start of the day, `to` uses the end of the day, and invalid date filters return `422 Unprocessable Entity`.

List endpoints are paginated with `page` and `per_page` query parameters. Defaults are `page=1` and `per_page=50`, with a maximum `per_page` of `100`.

```http
GET /api/v1/client/food_entries?page=2&per_page=25
```

### Error Responses

Errors use a consistent envelope:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Validation failed",
    "request_id": "8d4f2e0d-5b3a-47d2-a0cc-1df53f74d0a0",
    "details": [
      "Email is invalid"
    ]
  }
}
```

Common error codes:

- `unauthorized`
- `invalid_credentials`
- `invite_not_found`
- `invite_expired`
- `invite_already_accepted`
- `validation_failed`
- `invalid_date_filter`
- `invalid_pagination`
- `rate_limited`
- `internal_server_error`

### Success Response Envelopes

Resource endpoints now use explicit envelopes:

```json
{
  "data": {
    "id": 123
  }
}
```

List endpoints include pagination metadata:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total_count": 0,
    "total_pages": 0
  }
}
```

Authentication endpoints remain unwrapped and continue returning `token` plus the authenticated user payload.

Client authentication endpoints return both an access `token` and a `refresh_token`. Refresh tokens currently expire after 30 days and rotate on `/client/refresh`. JWT access tokens currently expire after 24 hours.

### OpenAPI Contract

The OpenAPI document at [docs/openapi.yaml](docs/openapi.yaml) covers the current implemented API surface:

- auth, invite acceptance, refresh/logout, and password reset
- practitioner client management and invite resend
- client profile, password, consents, health-record CRUD, and sync
- practitioner read-only client health-record views
- pagination, date filtering, response envelopes, and error envelopes
- GDPR export/delete

When frontend consumers need request/response fields, prefer the OpenAPI schemas over the README summaries.

## Data Model

- **Practitioner** — The naturopath. Manages clients via the dashboard.
- **Client** — End user on mobile apps. Belongs to a practitioner. Invite-only registration.
- **FoodEntry** — Meal type, description, timestamp, notes.
- **Symptom** — Name, severity (1-10), timestamp, duration, notes.
- **EnergyLog** — Energy level (1-10), timestamp, notes.
- **SleepLog** — Bedtime, wake time, quality (1-10), hours slept, notes.
- **WaterIntake** — Amount (ml), timestamp.
- **Supplement** — Name, dosage, timestamp, notes.
- **Consent** — GDPR consent records (type, version, granted/revoked timestamps).

## GDPR Compliance

This API handles health data classified as special category data under GDPR Article 9:

- Explicit consent tracking with versioning
- Right to access via data export endpoint
- Right to erasure via data deletion endpoint
- Consent records retained for legal compliance even after data deletion

## Production Configuration

Required or recommended environment variables:

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | Yes | Primary PostgreSQL connection |
| `RAILS_MASTER_KEY` | Yes if credentials are used | Decrypt Rails credentials |
| `JWT_SECRET_KEY` | Yes | Current JWT signing secret |
| `JWT_PREVIOUS_SECRET_KEY` | No | Previous JWT secret accepted during rotation |
| `JWT_KEY_VERSION` | No | Current JWT key ID. Defaults to `current` |
| `JWT_PREVIOUS_KEY_VERSION` | No | Previous JWT key ID. Defaults to `previous` |
| `JWT_ISSUER` | No | JWT issuer claim. Defaults to `naturopath-api` |
| `JWT_AUDIENCE` | No | JWT audience claim. Defaults to `naturopath-api-clients` |
| `REFRESH_TOKEN_SECRET` | Recommended | Secret used to digest refresh tokens. Falls back to Rails secret outside production-specific hardening. |
| `PASSWORD_RESET_TOKEN_SECRET` | Recommended | Secret used to digest password reset tokens. Falls back to Rails secret outside production-specific hardening. |
| `APP_TIME_ZONE` | No | Date-filter time zone. Defaults to `UTC` |
| `RAILS_LOG_LEVEL` | No | Structured application log verbosity |
| `CORS_ORIGINS` | Recommended | Allowed browser origins for the dashboard. Defaults to local development origin. |
| `MAILER_FROM` | Recommended | Default sender address for invite and password reset emails |
| `APP_HOST` / `MAILER_HOST` | Recommended | Host used for generated email links |
| `SMTP_ADDRESS` | Recommended for email | SMTP host. If absent, production mail delivery is not SMTP-backed. |
| `SMTP_PORT` | No | SMTP port. Defaults to `587` |
| `SMTP_DOMAIN` | No | SMTP HELO/domain value |
| `SMTP_USERNAME` | Depends on SMTP provider | SMTP username |
| `SMTP_PASSWORD` | Depends on SMTP provider | SMTP password |
| `SMTP_AUTHENTICATION` | No | SMTP auth mode. Defaults to `plain` |
| `SMTP_ENABLE_STARTTLS_AUTO` | No | Enables SMTP STARTTLS. Defaults to `true` |

Notes:

- Production requires `JWT_SECRET_KEY`; it does not fall back to `secret_key_base`.
- The app currently uses in-process memory cache in production for rate limiting. That is acceptable on a single node, but move to a shared cache before scaling horizontally.

## Operations Runbook

Deployment basics:

1. Set production env vars, especially `DATABASE_URL`, `JWT_SECRET_KEY`, and `APP_TIME_ZONE`.
2. Run `bin/rails db:migrate`.
3. Verify `/up` returns `200`.
4. Verify the CI jobs `scan_ruby`, `lint`, and `test` are green before merging.

Rollback basics:

1. Roll back the application release.
2. If the release included DB changes, run the matching Rails rollback only if the migration is known to be reversible and the data impact is understood.
3. Re-check `/up`, auth login, and GDPR export/delete flows after rollback.

Monitoring hooks:

- Auth failures and auth throttling are logged as structured app events.
- GDPR exports and deletions are logged as structured app events.
- Unhandled API exceptions are reported through `Rails.error.report` and logged with a request ID.

Recommended alerts:

- sustained increase in `auth.*` failures
- any `api.internal_error` events
- unexpected spikes in `gdpr.data_exported` or `gdpr.data_deleted`

## GitHub Setup

This repo ships CI in [`.github/workflows/ci.yml`](.github/workflows/ci.yml), but GitHub branch protection still needs to be configured in the repository settings. Require the `scan_ruby`, `lint`, and `test` checks on the default branch before treating CI as an enforced merge gate.
