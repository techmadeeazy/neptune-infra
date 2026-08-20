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
