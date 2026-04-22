# NaturoPath Codex Plan

## Scope

This plan replaces the older four-repo assumption in local docs with the current target system:

1. `naturopath-api` — Rails 7.2 shared backend
2. `naturopath-mobile` — React Native / Expo client app for iOS and Android
3. `naturopath-dashboard` — Next.js practitioner web app

The dashboard is practitioner-only. Clients do not use the dashboard; all client-facing flows, including invite acceptance, login, password reset/change, profile, health records, sync, consent, export, and deletion, belong in the mobile app.

The API repo already contains the core invite flow, JWT auth, health record CRUD, pagination, filtering, consent tracking, GDPR export/deletion, serializers, and request-spec coverage. This plan focuses on the remaining work needed to make the full system feature complete and shippable.

## Working Assumptions

- The user’s latest plan is the source of truth, even where current repo docs still reference separate native iOS and Android repos.
- `naturopath-dashboard` is practitioner-only and must not implement client login, client invite acceptance, or client password reset screens.
- `naturopath-mobile` is the only client UI. Invite and reset email links should ultimately target mobile deep links handled by the app.
- API deployment comes before dashboard or mobile feature work beyond scaffolding.
- Dashboard and mobile should be developed against the live API once the API production/staging environment is stable.
- Each repo should maintain its own CI, but shared API contracts must be treated as cross-repo dependencies.

## Delivery Order

1. Finish missing API capabilities.
2. Deploy API to production-like infrastructure.
3. Build dashboard and mobile in parallel against the deployed API.
4. Run end-to-end validation across invite, auth, logging, sync, profile, export, and deletion flows.
5. Ship private mobile distribution through TestFlight and Firebase App Distribution.

## Phase 1: API Completion (`naturopath-api`)

### 1.1 Contract and Gap Review

Goal: confirm which Claude plan items are already done, partially done, or missing in this repo before building on top of assumptions.

Audit source: current repo state in `config/routes.rb`, `app/controllers/api/v1/**/*`, `app/serializers/**/*`, `app/services/app_event_logger.rb`, `app/mailers/**/*`, `app/jobs/**/*`, and the request/serializer specs already present in this worktree.

Status legend:
- `[x]` done
- `[~]` partial
- `[ ]` missing

Planned feature audit:

| Feature | Status | Current repo evidence | Remaining gap |
| --- | --- | --- | --- |
| Token refresh | `[x]` done | `config/routes.rb` now exposes `client/refresh` and `client/logout`; `app/models/refresh_token.rb` persists hashed refresh tokens with expiry, rotation, and revocation; `app/controllers/api/v1/client_auth_controller.rb` issues refresh tokens on login/invite acceptance and rotates or revokes them; `spec/requests/client_refresh_tokens_spec.rb` covers success, invalid, expired, reused, and logout-revoked cases. | Keep the contract stable for mobile and add audit events later if session lifecycle logging becomes necessary. |
| Password reset | `[x]` done | `config/routes.rb` exposes `client/forgot_password` and `client/reset_password`; `app/models/password_reset_token.rb` persists hashed reset tokens with expiry and one-time use; `ClientMailer#password_reset` delivers reset links asynchronously; `ClientAuthController` resets passwords, revokes existing refresh tokens, and returns fresh auth tokens; `spec/requests/client_password_resets_spec.rb` covers request, unknown email, success, invalid, expired, reused, and invalid-password cases. | Configure production SMTP and mobile reset deep link before real client testing. |
| Client profile update | `[x]` done | `PATCH /api/v1/client/profile` is implemented in `app/controllers/api/v1/client/profile_controller.rb`; it permits `email`, `first_name`, `last_name`, and `date_of_birth`; `spec/requests/client_profile_and_consents_spec.rb` covers valid and invalid updates. | Keep editable fields aligned with the mobile profile form. |
| Bulk sync | `[x]` done | `POST /api/v1/client/sync` is implemented in `app/controllers/api/v1/client/sync_controller.rb`; six health-record tables now support `client_uuid`; serializers expose `client_uuid`; `spec/requests/client_sync_spec.rb` covers auth, mixed valid/invalid operations, duplicate retries, later upsert reconciliation, deletion, and malformed payloads. | Keep the sync response contract stable for mobile offline queueing. |
| Client-facing serializers | `[x]` done | New serializers cover profile, consent, practitioner, client, and all six health-record resources in `app/serializers/**/*`, with contract coverage in `spec/serializers/serializer_contract_spec.rb`. | Keep shapes stable and use them as the contract source. |
| Audit logging | `[~]` partial | `AppEventLogger` is wired for unauthorized access, rate limiting, login failures, invite sent/resent/accepted/expiry, GDPR export/delete, password reset request/completion/rejection, password change, and sync failures. | Add export/delete requested/completed distinctions if support workflows need them. |
| Action Mailer + background job setup | `[x]` done | Rails loads Action Mailer, `ApplicationMailer` exists, `ClientMailer#invite` and `ClientMailer#password_reset` are implemented, invite/password emails use `deliver_later`, and production mail/queue settings are ENV-driven in `config/environments/production.rb`. | Provide real SMTP and mobile invite/reset deep-link env vars before real client testing. |

Client-facing contract freeze:

| Contract area | Status | Current repo evidence | Decision |
| --- | --- | --- | --- |
| Auth payloads | `[x]` done | Client login, invite acceptance, refresh, reset-password success, and authenticated password-change success return unwrapped `{ token, refresh_token, client }` payloads; forgot-password and logout return `204 No Content`; practitioner login remains `{ token, practitioner }`. | Treat the client auth token contract as frozen for mobile work. |
| Envelope structure | `[x]` done | `ApplicationController` standardizes `{ data, meta }` for resources and lists, and `ErrorSerializer` standardizes error envelopes. | Treat the current envelope as frozen. |
| Pagination metadata | `[x]` done | `Paginatable`-backed list endpoints return `page`, `per_page`, `total_count`, and `total_pages`; request specs cover this shape. | Treat current pagination metadata as frozen. |
| Validation error format | `[x]` done | Validation failures return `error.code`, `error.message`, `request_id`, and `details`. | Treat current validation envelope as frozen. |
| Sync payload shape | `[x]` done | `POST /api/v1/client/sync` accepts `{ operations: [...] }`; each operation supports `op_id`, `resource_type`/`type`, `action` (`upsert` or `delete`), `id`, `client_uuid`, and resource `attributes`; responses return `{ data: [per-operation results], meta: { total, upserted, deleted, skipped, failed } }`; each result includes top-level `id`, and missing deletes return `status: "skipped"`. | Treat the sync contract as frozen before implementing the mobile offline queue. |

Exit criteria:
- A single source of truth exists for API status and missing work.
- No mobile or dashboard work depends on undocumented API behavior.

### 1.2 Auth Completion

Goal: complete client auth flows required by mobile and dashboard-adjacent operations.

Tasks:
- [x] Add refresh-token flow with rotation/revocation semantics.
- [x] Add forgot-password and reset-password flow.
- [x] Add authenticated client password-change flow.
- [x] Persist and revoke refresh tokens safely.
- [x] Deliver password reset emails via Action Mailer.
- [x] Add request specs for successful refresh, invalid/expired/reused refresh tokens, forgot password, reset password, and revoked token/logout behavior.

Exit criteria:
- Mobile can stay logged in without forcing repeated password entry.
- Password recovery works end-to-end outside the Rails console.

### 1.3 Client Self-Service API Completion

Goal: expose the remaining self-service functionality required by the client app.

Tasks:
- [x] Complete client profile update endpoint(s).
- [x] Complete consent management endpoints if any actions are still missing.
- [x] Ensure serializers for client-facing views are stable and minimal.
- [x] Add or refine validations for editable profile fields.
- [x] Add request specs for all editable profile and consent flows.

Exit criteria:
- A logged-in client can view and update their own profile and consents entirely through the API.

### 1.4 Offline Sync API

Goal: support mobile offline writes and deterministic reconciliation.

Tasks:
- [x] Add `POST /api/v1/client/sync` bulk sync endpoint.
- [x] Define supported resource payloads and batching rules.
- [x] Accept client-generated IDs such as `client_uuid` for deduplication.
- [x] Implement conflict behavior explicitly as server-wins / last-write-wins.
- [x] Return per-record sync results so the mobile app can reconcile local state.
- [x] Add request specs covering mixed valid/invalid records, duplicate retries, ordering/replay edge cases, and conflict resolution through later upserts.

Exit criteria:
- Mobile can enqueue writes offline and replay them safely.

### 1.5 Background Jobs, Email, and Audit Trail

Goal: make async and compliance-sensitive operations production-ready.

Tasks:
- Set up Action Mailer for real delivery in non-local environments.
- Add background processing for email and long-running tasks.
- Confirm GDPR export/deletion and auth-sensitive events are auditable.
- Expand application event logging where needed:
  - invite sent/resent
  - invite accepted
  - password reset requested/completed
  - export requested/completed
  - deletion requested/completed
  - sync failures of interest

Exit criteria:
- Emails are not sent inline on critical request paths unless intentionally accepted.
- Compliance and support investigations have enough event history.

### 1.6 Production Deployment

Goal: get the API live before front-end feature implementation depends on it.

Tasks:
- Choose Render or Railway.
- Provision:
  - Rails web service
  - managed Postgres
- Configure:
  - `DATABASE_URL`
  - `RAILS_MASTER_KEY`
  - `JWT_SECRET`
  - `REFRESH_TOKEN_SECRET`
  - `PASSWORD_RESET_TOKEN_SECRET`
  - SMTP credentials when real invite/reset emails are needed
  - `CLIENT_INVITE_URL` as the mobile invite deep-link base URL, for example `naturopath://accept-invite`
  - `CLIENT_PASSWORD_RESET_URL` as the mobile reset deep-link base URL, for example `naturopath://reset-password`
  - log level
- Enforce SSL in production.
- Run `db:migrate` and seed only the minimum required baseline data.
- Confirm CI gates deploys to `main` only after success.
- Disable preview/branch deploys unless there is a clear need.

Exit criteria:
- Production API is reachable, stable, and usable from Postman and external clients.

### 1.7 API Verification and Reference Data

Goal: create realistic, reusable integration data and validate the live environment.

Tasks:
- Build a Postman collection for:
  - practitioner creates/resends invite
  - client accepts invite using the mobile-facing API contract
  - client login
  - create/update/delete entries
  - sync
  - profile update
  - export
  - delete
- Add local and production environments.
- Create realistic practitioner/client records and health data through the API, not seeds.
- Verify production rate limiting, mail delivery, and GDPR flows.

Exit criteria:
- Dashboard and mobile teams can use real reference data against the deployed API.

## Phase 2: Practitioner Dashboard (`naturopath-dashboard`)

This phase starts after Phase 1.6 is complete. It can run in parallel with mobile once the API is live.

The dashboard is practitioner-only. It should not expose client login, invite acceptance, password reset, profile editing, health-record entry, offline sync, or GDPR self-service screens. Those belong to the mobile app.

### 2.1 Foundation

Tasks:
- Create Next.js app with TypeScript.
- Set up routing, env handling, linting, formatting, and CI.
- Define shared API client patterns:
  - typed envelopes
  - auth handling
  - pagination helpers
  - error normalization
- Decide whether shared types live in a separate package or are copied/generated.

Exit criteria:
- Dashboard can authenticate and fetch live API data from non-local environments.

### 2.2 Practitioner Auth and Client Management

Tasks:
- Practitioner login flow.
- Authenticated layout and session handling.
- Client list, detail view, create invite, resend/rotate invite, and copy/share invite-token fallback for development before email/deep links are live.
- Search/filter/sort decisions as needed from actual usage.

Exit criteria:
- A practitioner can manage clients and reach each client’s records from the dashboard without acting as the client.

### 2.3 Record Review Experience

Tasks:
- Build views for all six record types.
- Support date filtering, pagination, and empty states.
- Present record history in a way that is usable during consultations.
- Include profile and consent visibility where relevant.

Exit criteria:
- Practitioner can reliably review a client’s data without using Postman.

### 2.4 Practitioner Operations and Hardening

Tasks:
- Surface practitioner-only compliance visibility if needed, without implementing client self-service export/delete flows in the dashboard.
- Add loading/error states and production-grade auth failure handling.
- Validate against production API contracts.
- Add build verification and smoke tests.

Exit criteria:
- `npm run build` passes and the practitioner-only dashboard is usable against the deployed API.

## Phase 3: Client Mobile App (`naturopath-mobile`)

This phase starts after Phase 1.6 is complete. It can run in parallel with dashboard.

The mobile app is the only client UI. It owns invite acceptance, client auth, reset/change password, profile, health records, offline sync, consent, export, and delete-account flows.

### 3.1 Foundation

Tasks:
- Create Expo managed app with TypeScript.
- Establish project structure:
  - `screens/`
  - `components/`
  - `hooks/`
  - `services/`
  - `models/`
  - `navigation/`
- Add baseline dependencies:
  - `@react-navigation/native`
  - `@tanstack/react-query`
  - `expo-secure-store`
  - `react-native-mmkv`
  - `@react-native-community/netinfo`
- Configure `app.config.ts` for environment-based API URLs.

Exit criteria:
- App boots on iOS and Android simulators/devices and can target dev/staging/prod APIs.

### 3.2 Networking and Auth

Tasks:
- Implement typed API client around `fetch` or `axios`.
- Store access/refresh tokens in Secure Store.
- Refresh tokens automatically on `401`.
- Configure mobile deep links for invite and reset emails:
  - `naturopath://accept-invite?invite_token=...`
  - `naturopath://reset-password?reset_token=...`
- Support:
  - accept invite
  - login
  - auto-login
  - logout
  - forgot password
  - reset password
  - change password
- Normalize API errors for forms and session failures.

Exit criteria:
- Client auth flows are stable on fresh install, restart, logout, invite deep link, reset deep link, and expired-session recovery.

### 3.3 Health Record Features

Tasks:
- Build list + add/edit/delete flows for:
  - food entries
  - symptoms
  - energy logs
  - sleep logs
  - water intake
  - supplements
- Use React Query for fetch, pagination, pull-to-refresh, and cache invalidation.
- Keep UX patterns consistent across all six resources.

Exit criteria:
- A client can manage all six record types on both platforms.

### 3.4 Offline Support

Tasks:
- Persist pending mutations in MMKV.
- Track connectivity with NetInfo.
- Flush queued writes through the bulk sync endpoint.
- Mark unsynced items visibly in the UI.
- Reconcile responses with local records using `client_uuid`.

Exit criteria:
- Airplane-mode create/edit/delete flows recover cleanly after reconnection.

### 3.5 Profile, Consent, and GDPR

Tasks:
- Profile view/edit.
- Change password.
- Consent management.
- Export data request.
- Delete account flow with confirmation.

Exit criteria:
- Client self-service matches the API’s supported account lifecycle.

### 3.6 Distribution

Tasks:
- Configure EAS Build.
- Set up iOS builds for TestFlight submission.
- Set up Android builds for Firebase App Distribution.
- Document environment, signing, and release steps.
- Add CI or scripted release steps where they reduce manual error.

Exit criteria:
- Internal testers can install current builds on iOS and Android without local native setup.

## Cross-Repo Coordination

### Shared Contracts

Maintain a single tracked contract for:
- auth payloads
- mobile invite and reset deep-link URL shape
- refresh behavior
- error envelope
- pagination metadata
- sync request/response format
- health record schemas

If shared types are not extracted into a package, assign one repo as the contract source and update the others deliberately.

### Sequence Rules

- Do not start mobile offline queue implementation before the sync endpoint contract is fixed.
- Do not start production-like dashboard QA before API deployment is stable.
- Do not add client-facing screens to the dashboard; route client invite/reset/profile/record/GDPR flows to mobile.
- Do not enable real invite/reset emails for testers until the mobile app handles the corresponding deep links.
- Do not start TestFlight/Firebase distribution until auth, profile, and sync behavior are stable enough for repeatable tester flows.

## Suggested Codex Execution Backlog

Use this order after the repo audit above:

1. API audit event completion where operationally needed
2. API deploy + production verification
3. Dashboard scaffold + auth + client list
4. Mobile scaffold + auth + networking
5. Dashboard record review flows
6. Mobile record entry flows
7. Mobile offline queue + sync reconciliation
8. Mobile profile/GDPR/settings
9. Dashboard hardening
10. Mobile distribution setup
11. Full end-to-end system verification

## Verification Gates

### API

- `bundle exec rspec`
- `bundle exec rubocop`
- `bundle exec brakeman --quiet`
- Manual Postman validation against local and production

### Dashboard

- `npm run build`
- Manual auth and data review against local and production APIs

### Mobile

- Expo local/device testing
- Offline sync validation by toggling connectivity
- Successful EAS builds for iOS and Android

### Full System

Run this exact integration path against the deployed API:

1. Practitioner invites client
2. Client accepts invite from mobile deep-link flow
3. Client logs entries online and offline
4. Offline data syncs after reconnect
5. Practitioner sees resulting data in dashboard
6. Client updates profile and consent state in mobile
7. Client requests export
8. Client requests deletion

## Immediate Next Step

Immediate next step completed on 2026-04-11: the API gap audit above converts the planned feature list into a checked status table based on the current `naturopath-api` worktree, including uncommitted changes.

Implementation completed on 2026-04-12:

1. Refresh-token flow
2. Password reset flow
3. Client profile update endpoint
4. Bulk sync contract and endpoint
5. Invite mailer and production mail configuration
6. Sync top-level `id` and missing-delete `skipped` response semantics
7. Authenticated client password-change endpoint

Next API work:

1. Finish any operational audit event refinements needed for support
2. Deploy the API to Render or Railway
3. Build the Postman collection and production reference data
