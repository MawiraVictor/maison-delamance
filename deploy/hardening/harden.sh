#!/usr/bin/env bash
# Server hardening for the shop.piuskl.me VPS (Ubuntu 22.04/24.04 on Azure).
#
#   sudo ./harden.sh            # SSH on port 22
#   sudo ./harden.sh 2222       # if SSH listens on another port
#
# Does:  UFW firewall, Fail2ban, SSH key-only login, automatic security
#        updates, Apache/PHP information-leak and cookie hardening.
# Safe to run more than once.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SSH_PORT="${1:-22}"

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo"

# ---------------------------------------------------------------------------
# 0. Lock-out guard: password login is about to be switched off, so make sure
#    whoever is running this can already get in with an SSH key.
# ---------------------------------------------------------------------------
ADMIN_USER="${SUDO_USER:-root}"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
[ -s "$ADMIN_HOME/.ssh/authorized_keys" ] \
  || die "$ADMIN_USER has no keys in $ADMIN_HOME/.ssh/authorized_keys. Add your public key first (ssh-copy-id) or you will be locked out."
say "SSH key found for $ADMIN_USER"

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
say "Installing ufw, fail2ban, unattended-upgrades"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ufw fail2ban unattended-upgrades

# ---------------------------------------------------------------------------
# 2. Firewall: deny everything inbound except SSH (rate-limited), HTTP, HTTPS.
#    The Azure Network Security Group must also allow 80 and 443.
# ---------------------------------------------------------------------------
say "Configuring UFW"
ufw default deny incoming
ufw default allow outgoing
ufw limit "$SSH_PORT"/tcp comment 'SSH (rate limited)'
ufw allow 80/tcp  comment 'HTTP -> HTTPS redirect'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

# ---------------------------------------------------------------------------
# 3. SSH: keys only. Named 00-* so it wins over Ubuntu's 50-cloud-init.conf
#    (sshd uses the first value it reads).
#    Root keeps key-only access because the GitHub Actions deploy logs in as
#    root to install the Apache config.
# ---------------------------------------------------------------------------
say "Hardening SSH"
SSHD_DROPIN=/etc/ssh/sshd_config.d/00-hardening.conf
install -m 644 -o root -g root "$HERE/sshd-hardening.conf" "$SSHD_DROPIN"
if sshd -t; then
  systemctl reload ssh 2>/dev/null || systemctl reload sshd
else
  rm -f "$SSHD_DROPIN"
  die "sshd rejected the new config; it was removed and SSH is unchanged"
fi

# ---------------------------------------------------------------------------
# 4. Fail2ban: ban IPs that brute-force SSH or probe Apache, via UFW.
# ---------------------------------------------------------------------------
say "Configuring Fail2ban"
sed "s/__SSH_PORT__/$SSH_PORT/" "$HERE/jail.local" > /etc/fail2ban/jail.local
chmod 644 /etc/fail2ban/jail.local
systemctl enable --now fail2ban
systemctl restart fail2ban

# ---------------------------------------------------------------------------
# 5. Automatic security updates (Section 9: updates and patches)
# ---------------------------------------------------------------------------
say "Enabling unattended security upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl enable --now unattended-upgrades

# ---------------------------------------------------------------------------
# 6. Apache + PHP: hide versions, secure session cookies
# ---------------------------------------------------------------------------
say "Hardening Apache and PHP"
a2enmod -q headers
install -m 644 -o root -g root "$HERE/apache-security.conf" /etc/apache2/conf-available/security-hardening.conf
a2enconf -q security-hardening

for dir in /etc/php/*/apache2/conf.d; do
  [ -d "$dir" ] || continue
  install -m 644 -o root -g root "$HERE/php-hardening.ini" "$dir/99-hardening.ini"
done

apachectl configtest
systemctl reload apache2

# ---------------------------------------------------------------------------
# Report (screenshot this for the demo)
# ---------------------------------------------------------------------------
say "Done. Current state:"
ufw status verbose
fail2ban-client status
fail2ban-client status sshd
sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|maxauthtries) '
echo
echo "Before closing this session, open a NEW terminal and check you can still log in with your key."
