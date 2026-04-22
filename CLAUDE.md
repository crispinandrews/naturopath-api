# NaturoPath API

Rails 7.2 API backend for the NaturoPath health tracking platform.

## Project Context

This is one of three repos in the NaturoPath system:
- **naturopath-api** (this repo) — Rails API + PostgreSQL
- **naturopath-mobile** — React Native/Expo app for clients (iOS + Android)
- **naturopath-dashboard** — Next.js web app for the practitioner

Both clients (mobile, dashboard) consume this API.

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
- `POST client/login` — Client auth
- `POST client/accept_invite` — Accept invite and set password
- `POST client/forgot_password` — Request password reset email
- `POST client/reset_password` — Reset password with token
- `POST client/refresh` — Refresh access token
- `POST client/logout` — Revoke refresh token
- `GET/POST/PATCH/DELETE clients/` — Practitioner manages clients
- `POST clients/:id/resend_invite` — Rotate invite token and extend expiry
- `GET clients/:id/food_entries` (etc.) — Practitioner views client data
- `GET/POST/PATCH/DELETE client/food_entries` (etc.) — Client manages own entries
- `GET/PATCH client/profile` — Client profile (view and update)
- `PATCH client/password` — Authenticated client password change
- `POST client/sync` — Bulk sync offline entries
- `POST gdpr/export` — Client data export
- `DELETE gdpr/delete` — Client data deletion

## Key Design Decisions

- Single practitioner system — only one practitioner account, seeded or created via console
- Two auth types: Practitioner (dashboard) and Client (mobile apps), both JWT
- Refresh tokens, password reset, and email flows are client-only — the single practitioner re-authenticates via the dashboard login; no refresh/reset infrastructure needed for practitioners
- Clients are invite-only: practitioner creates client, client accepts invite
- All entry types scoped to client — clients can only access their own data
- Practitioner can only access their own clients' data
- GDPR: health data is special category, consent tracking, export, and deletion built in
- `Api::V1::Practitioner` namespace for practitioner-facing client data views
- `Api::V1::Client` namespace for client-facing self-service endpoints
- Use `::Practitioner` / `::Client` to avoid namespace collision with controller modules
- **Terminology**: use "client" not "patient" throughout the codebase

## Claude Code Behaviour Guidelines

- Avoid ownership-dodging behaviour: if you encounter an issue, take responsibility for it and work towards a solution instead of passing it on to someone else. Don't say things like "not caused by my changes" or say that it's "a pre-existing issue". Instead, acknowledge the problem and take initiative to fix it. Also, don't give up with excuses like "known limitation" and don't mark it for "future work".
- Avoid premature stopping: if you encounter a problem, don't stop at the first obstacle. Instead, keep pushing forward and find a way to overcome it. Don't say things like "good stopping point" or "natural checkpoint". Instead, keep going until you have a complete solution.
- Avoid permission-seeking behaviour: if you have the knowledge and capability to solve a problem, push through. Don't say things like "should I continue?" or "want me to keep going?". Instead, take initiative and act towards the solution.
- Do plan multi-step approaches before acting (plan which files to read and in what order, which tools to use, etc).
- Do recall and apply project-specific conventions from CLAUDE.md files.
- Do catch your own mistakes by applying reasoning loops and self-checks, and fix them before committing or asking for help.

### Use of tools

Adhere to the following guidelines when using tools:

- Always use a *Research-First approach*: Before using any tool, conduct thorough research to understand the context and requirements. This ensures that you use the most appropriate tool for the task at hand. Never use an Edit-First approach. You should prefer making surgical edits to the codebase instead of rewriting whole files or doing large, sweeping changes.
- Use *Reasoning Loops* very frequently. Don't be lazy and skip them. Reasoning loops are essential for ensuring the quality and accuracy of your work.

### Thinking Depth

When working on tasks that require complex problem-solving, always apply the highest *level of thinking depth*.

When thinking is shallow, the model outputs to the cheapest action available. We don't want that. We don't mind consuming more tokens if it means a better output. So always apply the highest level of thinking depth.

Never reason from assumptions, always reason from the actual data. You need to read and understand the actual code, publication or documentation in order to make informed decisions. Don't rely on assumptions or guesses, as they can lead to mistakes and misunderstandings.
