-- Table-level GRANTs for neptune_api_role, added as each migration lands.
-- NOT auto-run by Postgres init (init-scripts only fire once, on first
-- volume creation, before any Laravel migration has run — the tables don't
-- exist yet at that point). Run this manually after `php artisan migrate`,
-- and append to it every time a new migration adds a table neptune-api
-- needs to read/write:
--
--   docker exec -i neptune-postgres psql -U neptune -d neptune < 02-grants-post-migration.sql
--
-- neptune-api never gets these on admin_users — Lozy staff records are
-- neptune-admin's alone.

GRANT SELECT, INSERT, UPDATE, DELETE ON users, user_roles, companies, company_members TO neptune_api_role;
