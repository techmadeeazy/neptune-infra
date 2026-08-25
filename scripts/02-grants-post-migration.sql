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
-- neptune-api while a vessel is in draft. `vessels` is read-only here -
-- only neptune-admin ever writes it, on Stage 1 approval (PRD A1.5).
GRANT SELECT, INSERT, UPDATE, DELETE ON vessel_drafts TO neptune_api_role;
GRANT SELECT ON vessels TO neptune_api_role;

-- Owners upload/delete their own vessel photos, but never set status,
-- rejection_reason, reviewed_by, or reviewed_at directly - that's the
-- moderation action, neptune-admin only. No UPDATE grant here on purpose.
GRANT SELECT, INSERT, DELETE ON vessel_photos TO neptune_api_role;
