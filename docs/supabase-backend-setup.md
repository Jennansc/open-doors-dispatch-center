# Supabase backend setup — Open Doors Dispatch Center

## What this version does

The dispatch app's current data model is a browser snapshot (team, tickets, nextId, and auditLog). The Supabase adapter stores that snapshot in one private row per authenticated user. This preserves the existing simulator behavior while adding cloud persistence.

This is a first backend foundation, not a normalized production dispatch system. Concurrent editing is last-write-wins; relational tables, server-side dispatch validation, billing/account integration, and audit-grade fee events are future work.

## Supabase setup

1. Open the Supabase project used by the dispatch simulator.
2. In SQL Editor, run supabase/migrations/202611270001_dispatch_state.sql.
3. In Authentication → Sign In / Providers (the exact label may vary), enable Anonymous sign-ins for this training project.
4. Open Project Settings → API Keys and copy the browser-safe publishable/anon key. Do not copy a service_role or secret key.
5. Put the key in supabase-config.js, replacing PASTE_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE.
6. Commit the configuration change and deploy the site. The Supabase URL is prefilled from the project shown in the setup screenshots.

## How it behaves

- If the key is still a placeholder, the app remains in local browser mode.
- When configured, the app signs in anonymously, reads the current user's private dispatch_state row, and hydrates the app.
- If no cloud row exists yet, the current browser data is uploaded as the initial snapshot.
- Every subsequent save writes the snapshot to Supabase and updates the status indicator.
- Row-level security restricts every row to its own auth.uid().
- The app uses only a public browser key; the service-role key must never be shipped to GitHub Pages.

## Important training-simulator limitations

- Anonymous auth creates a per-browser identity. It provides cloud persistence for that browser session/profile, but does not automatically transfer the same identity to another device. Add a real sign-in/account-linking flow before relying on cross-device access.
- Snapshot syncing is last-write-wins. Do not edit the same dispatch data concurrently from multiple devices.
- The existing $85 after-hours rule remains in the app and stores one fee value per work order in the snapshot. This is not a payment processor or a live customer-account charge. A future normalized backend should enforce fee idempotency server-side and retain billing adjustments.
- Keep this project strictly fictional/training data. Do not enter real customer personal information or payment details.

## Smoke test

1. Load the deployed app and confirm the backend status says Supabase connected.
2. Create a clearly fictional work order during normal business hours; reload the page and confirm it remains.
3. Edit that work order to an after-hours appointment; confirm the fee shows once.
4. Reload and confirm the fee is still present once.
5. Change the appointment back to business hours and verify the current fee value is cleared according to the app's appointment-change behavior.
6. Create a second fictional work order and confirm it is stored in the same user's cloud snapshot.
7. If the status says cloud connection failed, inspect the browser console and confirm the migration, anonymous sign-in setting, project URL, and public key.

