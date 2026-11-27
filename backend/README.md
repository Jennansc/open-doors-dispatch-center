# Open Doors Dispatch Center — Cloud Backend Draft

**Status:** schema foundation on `feature/cloud-backend-foundation`; not deployed or connected to the live Pages app.

This draft uses Supabase Postgres + Auth + Row Level Security as the proposed hosted backend. It is intended to replace browser-only persistence so an authenticated dispatcher can access the same training data from Chromebook and iPhone. No Supabase project or credentials have been connected yet.

## Current application state

The existing GitHub Pages app is a training simulator. It currently stores its team and work orders in Safari/browser local storage (`od_team`, `od_tickets`, `od_audit`, `od_next`). This backend draft does not change, clear, import, or overwrite those values. Keep the current app working while the backend is reviewed and tested separately.

## Schema migrations

Run these files in order in a new Supabase project's SQL Editor:

1. `supabase/001_initial_schema.sql`
2. `supabase/002_security_and_tenant_integrity.sql`
3. `supabase/003_create_organization_rpc.sql`
4. `supabase/004_work_order_audit.sql`
5. `supabase/005_membership_role_guard.sql`
6. `supabase/006_authenticated_api_grants.sql`
7. `supabase/007_server_side_schedule_and_fee_rules.sql`
8. `supabase/008_api_integrity_hardening.sql`
9. `supabase/009_membership_integrity.sql`

The schema provides organizations, role-based membership, technicians, work orders, and append-only work-order history. Roles: `owner`, `admin`, `dispatcher`, `technician`, `viewer`. RLS isolates organization data. Cross-organization technician assignment is blocked by a composite foreign key. Deletion must use `delete_work_order_with_reason` so the reason and deleted snapshot are retained. Role-management policies restrict owner promotion to owners. Explicit authenticated API grants are guarded by RLS; anonymous table access is revoked. Migration 008 removes direct work-order deletion so deletes must pass through the reasoned audit RPC, disables direct organization deletion until a safe workflow exists, makes audit history API-append-only, and protects organization ownership, work-order numbers, creator, and creation timestamps from client edits. Migration 009 keeps membership identity fields immutable and prevents removing or demoting the last organization owner.

The server-side scheduling trigger validates future appointments using each organization's `tz_name` (default `America/New_York`), assigned technician availability and shift, and 60-minute appointment overlap rules. It computes the $85 after-hours fee when an appointment extends beyond 5:00 PM and preserves the saved fee if the appointment details are unchanged. These rules need to be exercised in a test Supabase project before app integration.

## Safe setup sequence

1. Create a Supabase project under the account that will own the training environment.
2. Apply the migrations in order and review any SQL errors before proceeding.
3. Enable email authentication and create a test account.
4. Call the authenticated RPC `create_organization(org_name)` to create the organization and its first owner membership atomically.
5. Create test technician/work-order records and verify RLS with a second account from another organization.
6. Build and test a separate frontend adapter (`supabase/adapter.js`); only then plan a staged integration with the current app.

The Supabase project URL and publishable/anon key may be used in a browser client **only with RLS enabled and tested**. Never put a `service_role` or secret key in GitHub Pages, source code, or a browser.

## Backend smoke test

After applying migrations 001–009 in the Supabase test project, open the static diagnostic page at `backend/supabase/smoke-test.html` (once this branch is deployed). It accepts the browser-safe project URL/key and a test account, lets you create or select an organization, and runs a fictional work-order test:

- normal appointment fee is $0
- changing to 5:30 PM produces $85
- updating a different field preserves the same $85 fee
- moving back to a 4:00 PM appointment clears the current fee
- the temporary work order is removed through the reasoned delete RPC
- create/update/delete events are checked in the audit trail

The test retains the organization and audit history; it does not process payments. If cleanup fails, the page reports the work-order number so it can be removed manually through the audited workflow.

## Safety / non-goals

- Training data only; do not enter real customer data, payment details, or protected information.
- No production dispatch, billing, SMS, or real customer workflow is enabled.
- No existing local-storage records are automatically migrated.
- No backend is live until a Supabase project is provisioned and the adapter is implemented, tested, and approved.
