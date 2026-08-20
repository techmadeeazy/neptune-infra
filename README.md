# neptune-infra

Local dev services (`docker-compose.yml`) and deployment/network configuration
for the Neptune Platform. Kept in its own repo, separate from `neptune-admin`,
because infra/network topology (IP allowlists, DB roles, origin layout) is
sensitive on its own — ops may need access to this without needing the
Laravel admin business logic in `neptune-admin`.

## Local dev

    docker compose up -d

Starts: PostgreSQL 15, Redis 7, Elasticsearch 8 (production search target),
Meilisearch (lightweight local-dev default), MinIO (S3-compatible), MailHog,
and nginx (host-based admin/user separation — see below).

`init-scripts/01-roles.sql` creates the two least-privilege Postgres roles
(`neptune_api_role`, `neptune_admin_role`) and grants `neptune_admin_role`
schema-level `CREATE` — it owns migrations, so it needs DDL rights;
`neptune_api_role` never gets `CREATE`, only per-table DML.

After the first `php artisan migrate` in `neptune-admin` (and after any
migration that adds a table `neptune-api` needs), run
`scripts/02-grants-post-migration.sql` manually:

    docker exec -i neptune-postgres psql -U neptune -d neptune < scripts/02-grants-post-migration.sql

It deliberately lives in `scripts/`, not `init-scripts/` — anything in
`init-scripts/` is mounted to Postgres's `/docker-entrypoint-initdb.d` and
auto-runs on first volume creation, before any Laravel migration exists, so
a script assuming the tables already exist can't live there (it broke the
container's first boot once already).
Row-Level Security on `invoices`/`payments`/`payouts` lands the same way
once those tables exist.

## Admin/user separation, wired for real (2026-08-18)

`neptune-web`, `neptune-api`, and `neptune-admin` each run on the host (`pnpm
dev`, `php artisan serve`), not inside this docker-compose — nginx here
proxies to them by host header, so the separation that's documented in
`Architecture.md` §9 is actually exercised locally, not just assumed for
production:

| Host | Proxies to | Restriction |
|------|------------|-------------|
| `app.neptune.local` | neptune-web `:3000` | none — public |
| `api.neptune.local` | neptune-api `:3001` | none — public |
| `admin.neptune.local` | neptune-admin `:8000` | IP allowlist (`nginx/allowlist.conf`), enforced again inside Laravel by `EnsureAdminIpAllowlisted` |

To use it locally, add to `/etc/hosts`:

    127.0.0.1 app.neptune.local api.neptune.local admin.neptune.local

Then `docker compose up -d nginx` (with the other app repos running on their
usual ports) and hit `http://admin.neptune.local` / `http://app.neptune.local`
instead of raw `localhost` ports — this is what actually proves the two
surfaces don't share a cookie scope, rather than just trusting they will in
production. Hitting the raw `localhost:8000` / `localhost:3000` ports still
works too (nginx is additive, not the only path in) — that's fine for normal
day-to-day dev where the separation isn't what's being tested.

`nginx/allowlist.conf`'s `127.0.0.1`/`::1` default matches
`neptune-admin/.env`'s `ADMIN_IP_ALLOWLIST` — update both together.

## Production topology (decided 2026-08-18)

- **Two separate origins**: the admin app and the user-facing apps must not
  share a domain or cookie scope — e.g. `admin.neptune.io` (neptune-admin) vs
  `app.neptune.io` (neptune-web) + its API. Real TLS/domain setup depends on
  the hosting provider, not yet chosen — `nginx/conf.d/*.conf` here are the
  local-dev equivalents to adapt once that's decided.
- **Admin network access**: IP allowlist in front of `admin.neptune.io`, plus
  mandatory MFA on login (MFA itself is application-layer, implemented in
  `neptune-admin`'s auth — not yet built, see task backlog). Not open to the
  whole internet with MFA alone, and not a full VPN.
- **Search**: Elasticsearch is the production target; OpenSearch is an
  acceptable fallback. Meilisearch is local-dev-only.
- **Database**: one shared PostgreSQL instance/database; isolation comes from
  per-service least-privilege roles plus Row-Level Security on money tables,
  not separate databases.

Real IP ranges (replacing the loopback-only default) and TLS certs are still
pending a hosting decision — everything else in the separation (host routing,
allowlist enforcement, no shared cookies) is wired up now rather than
deferred.

## Commits

Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, etc.) — enforced by commitlint via a husky `commit-msg` hook. Runs automatically once you `pnpm install`.
