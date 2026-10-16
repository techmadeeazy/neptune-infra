#!/bin/sh
# Pulls the newest images and brings Neptune up. Run as root on the server
# from a checkout of neptune-infra. Migrations run before the new code
# starts, then neptune-api's grants are applied again, since a migration can
# add a table it needs.
#
#   ./deploy.sh            deploys the "dev" tag CI pushes from main
#   NEPTUNE_TAG=<sha> ./deploy.sh   deploys (or rolls back to) one commit
set -eu

cd "$(dirname "$0")"

docker compose pull

docker compose run --rm --no-deps neptune-admin php artisan migrate --force

# Reference data (vessel classes, document types, platform settings). Every
# seeder uses firstOrCreate, so running it again changes nothing.
docker compose run --rm --no-deps neptune-admin php artisan db:seed --force

sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d neptune < ../../scripts/02-grants-post-migration.sql

mkdir -p admin-build
docker compose up -d --remove-orphans

# The proxy serves the admin's CSS and JS from here. Copied into the same
# folder (not replacing it) so the proxy's mount keeps pointing at it; old
# hashed files left behind are small and harmless.
docker compose cp neptune-admin:/var/www/html/public/build/. admin-build/

# The proxy keeps no state, so reloading it picks up a renewed certificate
# or an edited allowlist without dropping connections.
docker compose exec neptune-proxy nginx -s reload

docker compose ps
