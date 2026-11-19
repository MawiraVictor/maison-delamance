# Maison Delamance Ecommerce Website

An ecommerce site built with PHP 8.3 and MySQL. You can run it locally with Docker. In production it is served by Apache2 over HTTPS at **https://shop.piuskl.me**.

## Run it locally (Docker)

1. Clone the repository.

   ```bash
   git clone https://github.com/kakeetopius/maison-delamance.git maison-delamance
   cd maison-delamance
   ```

2. Make sure Docker and Docker Compose are installed. If they aren't, install them with your package manager.

3. Start the containers.

   ```bash
   docker compose up -d
   ```

4. Open the website in your browser.

   ```text
   http://localhost:8080
   ```

5. When you're done, stop the containers.

   ```bash
   docker compose down
   ```

## Production deployment (Apache2 + TLS)

| File | Purpose |
|---|---|
| [`deploy/apache/shop.piuskl.me.conf`](deploy/apache/shop.piuskl.me.conf) | Apache2 virtual host for `shop.piuskl.me` |
| [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) | Deploys automatically to the VPS on every push to `main` |
| [`deploy/README.md`](deploy/README.md) | Detailed setup guide and an explanation of each setting |

### Server layout

| What | Path on server |
|---|---|
| Site code | `/var/www/shop` |
| Vhost config | `/etc/apache2/sites-available/shop.piuskl.me.conf` |
| TLS certificate | `/etc/ssl/certs/shop.piuskl.me.crt` |
| TLS private key | `/etc/ssl/private/shop.piuskl.me.key` |
| Logs | `/var/log/apache2/shop.piuskl.me-{access,error}.log` |

### What the vhost config does

- **HTTP → HTTPS:** port 80 sends every request to HTTPS with a `301` redirect.
- **TLS:** port 443 serves the site. Only TLS 1.2 and 1.3 are allowed. SSLv3, TLS 1.0 and TLS 1.1 are disabled.
- **Security headers:**
  - HSTS (one year)
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: SAMEORIGIN`
  - `Referrer-Policy`
- **Blocked paths:** `config/`, `includes/`, `modal/`, `control/`, `misc/`, `deploy/`, `.git`, hidden files, and repo files such as `docker-compose.yml` all return `403 Forbidden`. That keeps the database credentials private.
- **Routing:** `AcceptPathInfo On` lets the frontend call API routes like `/index.php/cart/get`.
- **Directory listings** are disabled and `.htaccess` overrides are ignored.

### File permissions

| Path | Owner | Mode |
|---|---|---|
| Site directories | `root:www-data` | `750` |
| Site files | `root:www-data` | `640` |
| TLS private key | `root:root` | `600` |
| TLS certificate | `root:root` | `644` |
| Vhost config | `root:root` | `644` |

Apache (`www-data`) can only read the code. If someone got PHP code execution, they still couldn't change the site files.

### Automatic deployment

Every push to `main` runs the **Deploy** workflow, which:

1. Uses `rsync` over SSH to copy the repo to `/var/www/shop`. It applies the permissions above (`D750,F640`, `root:www-data`) and skips `.git/`, `.github/` and `config/config.json`.
2. Installs and enables every `deploy/apache/*.conf` as an Apache site.
3. Runs `apachectl configtest`. Apache is reloaded only if the config is valid. Otherwise the job fails and the old config keeps serving.

The workflow needs these repository secrets: `VPS_SSH_KEY`, `VPS_HOST`, `VPS_USER`, and optionally `VPS_PORT`. The optional `DEPLOY_PATH` variable defaults to `/var/www/shop`.
