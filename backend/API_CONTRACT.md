# Backend API contract (frontend adapter plan)

This describes the first client adapter. It is not wired into `index.html` yet.

## Authentication and organization

- Sign up / sign in / sign out through Supabase Auth.
- After sign-in, query `organization_members` for the current user to discover their organizations (RLS limits the rows to memberships).
- Create an organization with RPC `create_organization({ org_name })`; the RPC returns the new organization UUID and inserts the caller as owner.
- Keep the selected `organization_id` in app session state, not as a trusted authorization decision. Every table query is still protected by RLS.

## Data mapping

| Current simulator field | Backend field |
| --- | --- |
| `customer` | `work_orders.customer_name` |
| `address` | `work_orders.service_address` |
| `phone` | `work_orders.callback_phone` |
| `issue` | `work_orders.issue` |
| `priority` | `work_orders.priority` |
| `status` | `work_orders.status` |
| `assigned` (technician name) | `work_orders.assigned_technician_id` (UUID) |
| `date` | `work_orders.appointment_date` |
| `time` | `work_orders.appointment_time` |
| `afterHoursFee` | `work_orders.after_hours_fee` (server-calculated and saved; never client-overwritten or recalculated on display) |
| technician `name` | `technicians.display_name` |
| technician `skill` | `technicians.specialty` |
| technician `available` | `technicians.is_available` |

## Initial adapter operations

- `loadWorkspace(organizationId)`: load technicians and work orders for the selected organization.
- `createWorkOrder(input)`: insert with `organization_id`, `created_by`, `updated_by`; audit trigger records creation and the database calculates the fee.
- `updateWorkOrder(id, patch)`: update with `updated_by`; audit trigger records old/new snapshots and classifies status/assignment changes.
- `deleteWorkOrder(id, reason)`: call `delete_work_order_with_reason`; never issue a direct client DELETE.
- `createTechnician(input)`, `updateTechnician(id, patch)`: use organization-scoped rows; only owner/admin/dispatcher can write.
- `loadAudit(organizationId)`: read `work_order_audit`; only owner/admin/dispatcher may view it.

## Migration requirements

Before replacing local storage:

1. Add an explicit sign-in and organization-selection screen.
2. Test two separate organizations and confirm they cannot read or modify each other's records.
3. Test role matrix (viewer read-only; technician read access; dispatcher work-order/technician operations; admin/owner management).
4. Keep a read-only local backup/export path and do not silently upload existing browser data.
5. Test saved fee preservation, 60-minute conflict checks, technician shift/workload validation, past-time validation, and completed-order history against server data.
6. Switch storage behind a feature flag; keep the existing local-only mode until remote tests pass.

Migration 007 adds database-side validation for future appointment times, technician shift/availability, overlapping active appointment windows, and the $85 after-hours fee rule. It is not yet tested in a live Supabase project. The schema still requires a disposable-project migration run and role/tenant tests before the backend should be connected to the current simulator.
