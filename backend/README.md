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

The schema provides organizations, role-based membership, technicians, work orders, and append-only work-order history. Roles: `owner`, `admin`, `dispatcher`, `technician`, `viewer`. RLS isolates organization data. Cross-organization technician assignment is blocked by a composite foreign key. Deletion must use `delete_work_order_with_reason` so the reason and deleted snapshot are retained.

## Safe setup sequence

1. Create a Supabase project under the account that will own the training environment.
2. Apply the migrations in order and review any SQL errors before proceeding.
3. Enable email authentication and create a test account.
4. Call the authenticated RPC `create_organization(org_name)` to create the organization and its first owner membership atomically.
5. Create test technician/work-order records and verify RLS with a second account from another organization.
6. Build and test a separate frontend adapter; only then plan a staged integration with the current app.

The Supabase project URL and publishable/anon key may be used in a browser client **only with RLS enabled and tested**. Never put a `service_role` or secret key in GitHub Pages, source code, or a browser.

## Safety / non-goals

- Training data only; do not enter real customer data, payment details, or protected information.
- No production dispatch, billing, SMS, or real customer workflow is enabled.
- No existing local-storage records are automatically migrated.
- No backend is live until a Supabase project is provisioned and the adapter is implemented, tested, and approved.
