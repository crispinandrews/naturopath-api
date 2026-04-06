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

### Test Credentials (development)

| Role | Email | Password |
|------|-------|----------|
| Practitioner | practitioner@example.com | password123 |
| Client 1 | client1@example.com | password123 |
| Client 2 | client2@example.com | password123 |

## API Endpoints

All endpoints are under `/api/v1/`.

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/practitioner/register` | Register a new practitioner |
| POST | `/practitioner/login` | Practitioner login |
| POST | `/client/login` | Client login |
| POST | `/client/accept_invite` | Accept invite and set password |

All authenticated endpoints require a JWT token in the `Authorization: Bearer <token>` header.

### Practitioner Endpoints

Require practitioner authentication.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/clients` | List all clients |
| POST | `/clients` | Create (invite) a new client |
| GET | `/clients/:id` | View client details |
| PATCH | `/clients/:id` | Update client |
| DELETE | `/clients/:id` | Delete client |
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
