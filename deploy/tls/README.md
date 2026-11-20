# ZeroSSL certificate with automatic renewal (course section 8)

## Run

1. Cloudflare → My Profile → API Tokens → Create Token → **Edit zone DNS**, limited to `piuskl.me`.
2. Run:
   ```bash
   cd /var/www/shop
   sudo CF_Token=xxxx ACME_EMAIL=you@example.com bash deploy/tls/setup-zerossl.sh
   ```

This gets one **ZeroSSL** certificate for `piuskl.me` and `*.piuskl.me` through a DNS challenge, so it covers `shop`, `status` and any later subdomain. It's installed where the vhosts already look (`/etc/ssl/certs/shop.piuskl.me.crt`, key in `/etc/ssl/private/`, mode 600). acme.sh's daily cron renews it about 30 days before expiry and reloads Apache only if `apachectl configtest` passes.

**Demo evidence:** the script's output showing `issuer=... ZeroSSL ...`, `~/.acme.sh/acme.sh --list`, and the cron entry. Force a renewal live with `sudo /root/.acme.sh/acme.sh --renew -d piuskl.me --ecc --force`.

## Rollback

The script backs up the previous certificate next to it (`*.bak-<timestamp>`):

```bash
sudo cp /etc/ssl/certs/shop.piuskl.me.crt.bak-<ts> /etc/ssl/certs/shop.piuskl.me.crt
sudo cp /etc/ssl/private/shop.piuskl.me.key.bak-<ts> /etc/ssl/private/shop.piuskl.me.key
sudo /root/.acme.sh/acme.sh --remove -d piuskl.me --ecc   # stop renewing
sudo systemctl reload apache2
```
