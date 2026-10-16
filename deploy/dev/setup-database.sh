#!/bin/sh
# Creates Neptune's database and its two roles on the server's own Postgres,
# with the passwords setup-env.sh wrote into api.env and admin.env. Run as
# root on the server, after setup-env.sh. Safe to run again: existing roles
# get their password reset to the one in the env files, and an existing
# database is left alone. Regency's databases are never touched.
#
# neptune_admin_role owns the database, so it can run the Laravel
# migrations. neptune_api_role only gets table grants, applied by deploy.sh
# after each migration.
set -eu

cd "$(dirname "$0")"

ADMIN_DB_PASSWORD=$(sed -n 's/^DB_PASSWORD=//p' admin.env)
API_DB_PASSWORD=$(sed -n 's|^DATABASE_URL=postgresql://neptune_api_role:\([^@]*\)@.*|\1|p' api.env)

if [ -z "$ADMIN_DB_PASSWORD" ] || [ -z "$API_DB_PASSWORD" ]; then
    echo "Could not read both database passwords. Run setup-env.sh first." >&2
    exit 1
fi

# The passwords go in on standard input, so they never show in the process
# list.
sudo -u postgres psql -v ON_ERROR_STOP=1 -q <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'neptune_admin_role') THEN
        CREATE ROLE neptune_admin_role WITH LOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'neptune_api_role') THEN
        CREATE ROLE neptune_api_role WITH LOGIN;
    END IF;
END
\$\$;
ALTER ROLE neptune_admin_role WITH PASSWORD '$ADMIN_DB_PASSWORD';
ALTER ROLE neptune_api_role WITH PASSWORD '$API_DB_PASSWORD';
SQL

if [ "$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'neptune'")" != "1" ]; then
    sudo -u postgres createdb --owner=neptune_admin_role neptune
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d neptune <<SQL
REVOKE ALL ON DATABASE neptune FROM PUBLIC;
GRANT CONNECT ON DATABASE neptune TO neptune_admin_role, neptune_api_role;
GRANT USAGE ON SCHEMA public TO neptune_api_role;
SQL

echo "Database neptune and both roles are ready."
