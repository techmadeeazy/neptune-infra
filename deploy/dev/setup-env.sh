#!/bin/sh
# Writes api.env, admin.env and meilisearch.env from their examples, with a
# fresh random value for every {{...}}. Run once on the server. The values
# are generated here and never printed, so no secret passes through git or
# a chat. The files are made readable by root only.
#
# It refuses to run when any of the three already exists: the keys shared
# between them (the internal API keys, the search key) must come from the
# same run, so a partial rewrite would leave the apps unable to talk.
set -eu

cd "$(dirname "$0")"

for name in api admin meilisearch; do
    if [ -e "$name.env" ]; then
        echo "$name.env already exists. Nothing was changed." >&2
        exit 1
    fi
done

hex() {
    openssl rand -hex 32
}

API_DB_PASSWORD=$(hex)
ADMIN_DB_PASSWORD=$(hex)
JWT_SECRET=$(hex)
TOTP_ENCRYPTION_KEY=$(hex)
API_INTERNAL_KEY=$(hex)
ADMIN_INTERNAL_API_KEY=$(hex)
MEILI_MASTER_KEY=$(hex)
APP_KEY="base64:$(openssl rand -base64 32)"

umask 077
for name in api admin meilisearch; do
    sed \
        -e "s|{{API_DB_PASSWORD}}|$API_DB_PASSWORD|g" \
        -e "s|{{ADMIN_DB_PASSWORD}}|$ADMIN_DB_PASSWORD|g" \
        -e "s|{{JWT_SECRET}}|$JWT_SECRET|g" \
        -e "s|{{TOTP_ENCRYPTION_KEY}}|$TOTP_ENCRYPTION_KEY|g" \
        -e "s|{{API_INTERNAL_KEY}}|$API_INTERNAL_KEY|g" \
        -e "s|{{ADMIN_INTERNAL_API_KEY}}|$ADMIN_INTERNAL_API_KEY|g" \
        -e "s|{{MEILI_MASTER_KEY}}|$MEILI_MASTER_KEY|g" \
        -e "s|{{APP_KEY}}|$APP_KEY|g" \
        "$name.env.example" > "$name.env"
done

echo "Wrote api.env, admin.env and meilisearch.env (mode 600)."
echo "Now fill in the values marked 'you set' in api.env and admin.env."
