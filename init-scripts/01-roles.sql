-- Least-privilege Postgres roles for neptune-api and neptune-admin.
-- Decision (2026-08-18): one shared database, but each service connects with
-- its own role instead of a shared superuser-style credential. GRANTs are
-- scoped per-table once schema/migrations land (chunk 2, owned by
-- neptune-admin's Laravel migrations). Row-Level Security policies on
-- invoices/payments/payouts also land in chunk 2, layered on top of these
-- roles.
--
-- Change the placeholder passwords before any non-local use — these match
-- the placeholders in neptune-api/.env.example and neptune-admin/.env.example.

CREATE ROLE neptune_api_role WITH LOGIN PASSWORD 'changeme';
CREATE ROLE neptune_admin_role WITH LOGIN PASSWORD 'changeme';

GRANT CONNECT ON DATABASE neptune TO neptune_api_role, neptune_admin_role;

-- neptune-admin owns migrations, so it needs schema-level DDL rights.
-- neptune-api never runs migrations and never gets CREATE — see the
-- per-table GRANTs added alongside each migration for its data access.
GRANT CREATE ON SCHEMA public TO neptune_admin_role;

-- Table-level GRANTs for neptune_api_role are added per-migration as each
-- table lands (see database/migrations in neptune-admin) — do not grant
-- blanket ALL PRIVILEGES here.
