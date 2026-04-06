# NaturoPath API

Rails 7.2 API backend for the NaturoPath health tracking platform.

## Project Context

This is one of four repos in the NaturoPath system:
- **naturopath-api** (this repo) — Rails API + PostgreSQL
- **naturopath-dashboard** — Next.js web app for the practitioner
- **naturopath-ios** — Swift/SwiftUI iOS app for clients
- **naturopath-android** — Kotlin/Jetpack Compose Android app for clients

All three clients (dashboard, iOS, Android) consume this API.

## Stack

- Ruby 3.4.5, Rails 7.2 (API mode)
- PostgreSQL
- JWT authentication (via `jwt` gem)
- bcrypt for password hashing

## Common Commands

```bash
bin/rails server              # Start dev server (port 3000)
bin/rails db:migrate          # Run migrations
bin/rails db:seed             # Seed test data
bin/rails routes              # List all routes
bin/rails console             # Rails console
```

## Test Credentials (development)

- Practitioner: `practitioner@example.com` / `password123`
- Client 1: `client1@example.com` / `password123`
- Client 2: `client2@example.com` / `password123`

## API Structure

All endpoints under `/api/v1/`:

- `POST practitioner/login` — Practitioner auth
- `POST practitioner/register` — Practitioner registration
- `POST client/login` — Client auth
- `POST client/accept_invite` — Accept invite and set password
- `GET/POST/PATCH/DELETE clients/` — Practitioner manages clients
- `GET clients/:id/food_entries` (etc.) — Practitioner views client data
- `GET/POST/PATCH/DELETE client/food_entries` (etc.) — Client manages own entries
- `GET client/profile` — Client profile
- `POST gdpr/export` — Client data export
- `DELETE gdpr/delete` — Client data deletion

## Key Design Decisions

- Two auth types: Practitioner (dashboard) and Client (mobile apps), both JWT
- Clients are invite-only: practitioner creates client, client accepts invite
- All entry types scoped to client — clients can only access their own data
- Practitioner can only access their own clients' data
- GDPR: health data is special category, consent tracking, export, and deletion built in
- `Api::V1::Practitioner` namespace for practitioner-facing client data views
- `Api::V1::Client` namespace for client-facing self-service endpoints
- Use `::Practitioner` / `::Client` to avoid namespace collision with controller modules
- **Terminology**: use "client" not "patient" throughout the codebase
