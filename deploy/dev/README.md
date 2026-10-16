# Neptune on the dev server

Runs `neptune-api` and `neptune-admin` on the shared dev server
(137.184.28.207, Debian 13) beside the Regency stack. `neptune-web` is on
Vercel.

| What | Where |
|------|-------|
| API | `https://neptune-api.techmadeeazy.com:7443` (docs at `/docs`) |
| Admin console | `https://neptune-admin.techmadeeazy.com:7444`, allowlisted addresses only |
| Database | the server's own Postgres 16, database `neptune` |
| Images | `ghcr.io/techmadeeazy/neptune-api` and `neptune-admin`, built by each repo's CI on main |

Containers: `neptune-api`, `neptune-admin` (PHP-FPM), `neptune-admin-worker`,
`neptune-redis`, `neptune-meilisearch`, `neptune-proxy` (nginx, the only one
with published ports). The scheduler is a host cron line, not a container.
Each has a memory cap; together they stay under about 1.3 GB.

Ports 80 and 443 are left free on purpose, so certbot can renew in
standalone mode for this stack and for Regency's certificate.

## First time

Run as root on the server.

1. Let the server pull private images. Create a GitHub token that can only
   read packages and enter it at the prompt, so it never sits in shell
   history:

        docker login ghcr.io -u <github-user>

2. Check out this repo:

        git clone https://github.com/techmadeeazy/neptune-infra.git /var/www/html/neptune-platform/neptune-infra
        cd /var/www/html/neptune-platform/neptune-infra/deploy/dev

3. Write the settings files. Every secret is generated on the server and
   never printed:

        ./setup-env.sh

   Then fill in the values marked "you set" in `api.env` and `admin.env`:
   Gmail SMTP user and app password, Termii key, the Cloudinary account
   (the same in both files), the admin allowlist, and the Vercel address
   in `CORS_ALLOWED_ORIGINS`, `APP_PUBLIC_URL` and `OWNER_INVITATION_URL`.
   Private files are stored on Cloudinary as raw files and opened through
   signed download links, which work on the Free plan with no extra
   setting (checked against the real account on 2026-10-16).

4. Allow your addresses into the admin console:

        cp nginx/allowlist.conf.example nginx/allowlist.conf

   and edit it to match `ADMIN_IP_ALLOWLIST`. To add someone later, add
   their address to both, then run
   `docker compose up -d --force-recreate neptune-admin neptune-admin-worker`
   and `docker compose restart neptune-proxy` (a reload is not enough: the
   file is mounted on its own and the proxy keeps the old copy). Someone not
   on the list sees a page with their address to send you.

5. Create the database and its two roles:

        ./setup-database.sh

6. Get the certificate (port 80 must be free, which it is):

        certbot certonly --standalone --cert-name neptune \
            -d neptune-api.techmadeeazy.com -d neptune-admin.techmadeeazy.com \
            --deploy-hook "docker exec neptune-proxy nginx -s reload"

7. Open the two ports:

        ufw allow 7443/tcp
        ufw allow 7444/tcp

8. Deploy:

        ./deploy.sh

9. Create the first admin account. In tinker, with your own name, email
   and a strong password (the console asks for 2FA set-up at first sign-in):

        docker compose exec neptune-admin php artisan tinker
        >>> $a = new App\Models\Identity\AdminUser(['name' => '...', 'email' => '...', 'password' => '...']);
        >>> $a->forceFill(['role' => 'super_admin'])->save();

   Role is kept out of mass assignment on purpose and cannot be empty, so
   the account is built with `new` and saved once with the role set
   (`create()` would try to save it without one). The tinker history goes
   when the container is recreated.

10. Add the scheduler, which runs every minute:

        echo '* * * * * root docker exec neptune-admin php artisan schedule:run > /dev/null 2>&1' > /etc/cron.d/neptune

## Every deploy

Push to main in `neptune-api` or `neptune-admin`, wait for CI to push the
image, then on the server:

    cd /var/www/html/neptune-platform/neptune-infra && git pull && ./deploy/dev/deploy.sh

`deploy.sh` pulls the images, runs migrations and the reference data
seeders (both safe to repeat), applies `neptune-api`'s grants again,
restarts what changed and reloads nginx. To roll back, deploy an older
commit's image: `NEPTUNE_TAG=<commit sha> ./deploy/dev/deploy.sh`.

## Checking on it

    docker compose ps
    docker compose logs -f neptune-api
    curl -s https://neptune-api.techmadeeazy.com:7443/health
    docker stats --no-stream
