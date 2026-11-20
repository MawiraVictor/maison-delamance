#!/usr/bin/env bash
# Issue a ZeroSSL wildcard certificate (piuskl.me + *.piuskl.me) with acme.sh
# and renew it automatically.
#
#   sudo CF_Token=<cloudflare token> ACME_EMAIL=<your email> ./setup-zerossl.sh
#
# CF_Token: Cloudflare -> My Profile -> API Tokens -> Create Token ->
#           "Edit zone DNS" template, Zone Resources: piuskl.me only.
#
# Uses the DNS-01 challenge (acme.sh adds a temporary TXT record through the
# Cloudflare API), so it works for wildcards and no port 80 exception is needed.
# One certificate then covers shop., status. and any future subdomain.
#
# The certificate is installed to the paths the Apache vhosts already use,
# and acme.sh's daily cron renews it ~30 days before expiry and reloads Apache.
set -euo pipefail

DOMAIN="piuskl.me"
CERT=/etc/ssl/certs/shop.piuskl.me.crt
KEY=/etc/ssl/private/shop.piuskl.me.key
ACME="/root/.acme.sh/acme.sh"

die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
say() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || die "run with sudo"
: "${CF_Token:?set CF_Token to a Cloudflare API token with DNS edit rights on $DOMAIN}"
: "${ACME_EMAIL:?set ACME_EMAIL to the email for the ZeroSSL account}"
export CF_Token

if [ ! -x "$ACME" ]; then
  say "Installing acme.sh"
  apt-get install -y -q curl socat cron >/dev/null
  curl -fsSL https://get.acme.sh | sh -s email="$ACME_EMAIL"
fi

say "Using ZeroSSL as the certificate authority"
"$ACME" --set-default-ca --server zerossl
"$ACME" --register-account -m "$ACME_EMAIL" --server zerossl

say "Issuing certificate for $DOMAIN and *.$DOMAIN"
set +e
"$ACME" --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN" --keylength ec-256 --server zerossl
rc=$?
set -e
# 0 = issued, 2 = existing cert still valid (skipped). Anything else is an error.
[ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || die "acme.sh --issue failed (exit $rc)"

say "Backing up the current certificate"
ts="$(date +%Y%m%d-%H%M%S)"
[ -f "$CERT" ] && cp -a "$CERT" "$CERT.bak-$ts"
[ -f "$KEY" ]  && cp -a "$KEY"  "$KEY.bak-$ts"

say "Installing certificate and setting up automatic renewal"
"$ACME" --install-cert -d "$DOMAIN" --ecc \
  --key-file       "$KEY" \
  --fullchain-file "$CERT" \
  --reloadcmd      "chmod 600 $KEY && apachectl configtest && systemctl reload apache2"

chown root:root "$CERT" "$KEY"
chmod 644 "$CERT"
chmod 600 "$KEY"

say "Installed certificate (screenshot this):"
openssl x509 -in "$CERT" -noout -issuer -subject -dates -ext subjectAltName
echo
"$ACME" --list
echo
echo "Renewal cron job:"
crontab -l | grep acme.sh || echo "(no cron entry found - run: $ACME --install-cronjob)"
