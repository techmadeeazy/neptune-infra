-- Table-level GRANTs for neptune_api_role, added as each migration lands.
--
-- Deliberately lives in scripts/, not init-scripts/. init-scripts/ is
-- mounted to Postgres's /docker-entrypoint-initdb.d and every file in it
-- auto-runs on first volume creation, before any Laravel migration has run.
-- This file assumes the tables already exist, so it must never be in that
-- directory (it broke the container's first boot once already, see git
-- history). Run manually after `php artisan migrate`, and append to it
-- every time a new migration adds a table neptune-api needs to read/write:
--
--   docker exec -i neptune-postgres psql -U neptune -d neptune < scripts/02-grants-post-migration.sql
--
-- neptune-api never gets these on admin_users. Lozy staff records are
-- neptune-admin's alone.

GRANT SELECT, INSERT, UPDATE, DELETE ON users, user_roles, companies, company_members TO neptune_api_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON kyc_documents TO neptune_api_role;

-- Vessel classification reference tables are admin-managed only; neptune-api
-- reads them to populate the vessel registration form's dropdowns.
GRANT SELECT ON vessel_types, tonnage_bands, dp_classes, operational_certifications TO neptune_api_role;

-- Vessel draft CRUD (registration, rates, consumption declaration) lives in
-- neptune-api. The draft stays the owner's working copy after listing.
-- neptune-admin writes `vessels` on approval (PRD A1.5); neptune-api may
-- only change the columns that go live without review: the port location
-- and the rates (decided 2026-10-16).
GRANT SELECT, INSERT, UPDATE, DELETE ON vessel_drafts TO neptune_api_role;
GRANT SELECT ON vessels TO neptune_api_role;
GRANT UPDATE (
    current_port_location, rate_currency, daily_hire_rate, fuel_rate_per_litre,
    water_rate_per_litre, mobilization_fee, demobilization_fee, rate_visibility,
    rate_notes, updated_at
) ON vessels TO neptune_api_role;

-- Owners upload/delete their own vessel photos, but never set status,
-- rejection_reason, reviewed_by, or reviewed_at directly - that's the
-- moderation action, neptune-admin only. No UPDATE grant here on purpose.
GRANT SELECT, INSERT, DELETE ON vessel_photos TO neptune_api_role;

-- Same reasoning for vessel_documents: no UPDATE, moderation is
-- neptune-admin's alone. document_types is admin-managed reference data,
-- read-only here, same shape as the vessel classification tables.
GRANT SELECT, INSERT, DELETE ON vessel_documents TO neptune_api_role;
GRANT SELECT ON document_types TO neptune_api_role;

-- Owner-set standby/blocked periods (PRD A4) are created and removed in
-- neptune-api. No UPDATE on purpose: a period is replaced by deleting it
-- and adding a new one, so nothing can quietly move its dates around.
GRANT SELECT, INSERT, DELETE ON vessel_availability_periods TO neptune_api_role;

-- RFQ, charter and offline booking tables (PRD B1-B7). These were missing
-- from this file until the first real end-to-end run against a fresh
-- database showed neptune-api had no access to any of them. Each grant is
-- only what the API's repositories actually do: offers and notes are
-- append-only, RFQs and charters are never deleted, and an offline booking
-- is removed rather than edited.
GRANT SELECT, INSERT, UPDATE ON rfqs, charters, charter_extensions TO neptune_api_role;
GRANT SELECT, INSERT ON rfq_offers, rfq_notes, charter_notes TO neptune_api_role;
GRANT SELECT, INSERT, DELETE ON offline_bookings TO neptune_api_role;

-- Captain assignment and C-TRAC logs (PRD C1). An assignment is ended by
-- setting unassigned_at and a log can be edited inside its 48 hour window,
-- so both need UPDATE, but neither is ever deleted. The edit history is
-- append-only.
GRANT SELECT, INSERT, UPDATE ON vessel_captains, ctrac_logs TO neptune_api_role;
GRANT SELECT, INSERT ON ctrac_log_edits TO neptune_api_role;

-- Charter lifecycle (2026-10-14). A finished charter's row is moved from
-- charters to charter_history by neptune-admin, with the same id, so the
-- API has to be able to read it there. It never writes to it.
GRANT SELECT ON charter_history TO neptune_api_role;

-- The status log gets a row from the API for each step it takes
-- (confirmed, extension requested or answered, cancelled). Append-only.
GRANT SELECT, INSERT ON charter_status_history TO neptune_api_role;

-- Platform-wide rules set by finance admins, such as how charter days are
-- counted for estimates. Read-only here.
GRANT SELECT ON platform_settings TO neptune_api_role;

-- On-Hire and Off-Hire certificates (PRD C3/C4). neptune-admin creates
-- the draft and its lines. The Vessel Master and the Charterer fill it in
-- and sign it through the API, so it reads and updates but never creates
-- or deletes.
GRANT SELECT, UPDATE ON hire_certificates, hire_certificate_lines TO neptune_api_role;

-- A person's uploaded signature image. One row each, replaced in place.
GRANT SELECT, INSERT, UPDATE ON user_signatures TO neptune_api_role;

-- Daily ROB reports (PRD C2). Sent by the Vessel Master and editable
-- inside the 48 hour window. Approval is neptune-admin's alone, but it is
-- a column on the same row, so the API is trusted not to write it.
GRANT SELECT, INSERT, UPDATE ON rob_reports TO neptune_api_role;
-- A correction replaces the report's lines as a set, which needs DELETE.
-- The report row itself is never deleted.
GRANT SELECT, INSERT, DELETE ON rob_report_lines TO neptune_api_role;

-- Co-booking requests (PRD B3). Raised and answered through the API.
GRANT SELECT, INSERT, UPDATE ON co_booking_requests TO neptune_api_role;

-- Finance (PRD D). Invoices and payments are made by finance admins in
-- neptune-admin. The API only shows them to the people they belong to.
GRANT SELECT ON invoices, invoice_lines, payments, payment_allocations TO neptune_api_role;

-- Owners and brokers manage their own bank accounts and ask for payouts.
-- A payout is approved and settled in neptune-admin, so no UPDATE here.
GRANT SELECT, INSERT, UPDATE ON bank_accounts TO neptune_api_role;
GRANT SELECT, INSERT ON payouts TO neptune_api_role;

-- What the platform has earned in commission. Written by neptune-admin
-- when a payment is allocated. The API reads it so a payout is charged
-- the rate the commission was actually earned at.
GRANT SELECT ON platform_income TO neptune_api_role;

-- Terms put forward on a co-booking request, by either side. Append-only.
GRANT SELECT, INSERT ON co_booking_offers TO neptune_api_role;

-- Owner invitations (PRD A7.1 Mode 2) are made in neptune-admin. The API
-- reads one to check it was sent to the person accepting it, then asks
-- neptune-admin to hand over the vessels. It never writes the table.
GRANT SELECT ON owner_invitations TO neptune_api_role;

-- PRD B0 saved searches and favourite vessels: the signed-in client or
-- broker keeps, renames and removes their own.
GRANT SELECT, INSERT, UPDATE, DELETE ON saved_searches TO neptune_api_role;
GRANT SELECT, INSERT, DELETE ON favourite_vessels TO neptune_api_role;
