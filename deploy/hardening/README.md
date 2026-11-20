# Server hardening: firewall, Fail2ban, SSH (course section 9)

Once merged, the GitHub deploy copies this folder to `/var/www/shop/deploy/hardening/` (Apache blocks it from the web).

## Run

```bash
cd /var/www/shop
sudo bash deploy/hardening/harden.sh        # add the port number if SSH isn't on 22
```

| What | How |
|---|---|
| Firewall | UFW denies all inbound except 22 (rate limited), 80, 443 |
| Brute-force protection | Fail2ban jails: `sshd`, `apache-auth`, `apache-noscript`, `apache-botsearch`, plus `recidive` (3 bans in a day = 1 week ban). Bans go through UFW and get longer for repeat offenders |
| SSH | Key-only login, no passwords, root key-only (the GitHub deploy uses it), 3 attempts max |
| Patching | `unattended-upgrades` installs security updates daily |
| Apache | `ServerTokens Prod`, no signature, TRACE off |
| PHP | `expose_php` off, session cookie `Secure` + `HttpOnly` + `SameSite=Lax` |

The script refuses to run if your user has no SSH key, so you can't lock yourself out. Still, **keep your current session open and test a new login** before closing it.

> Azure: the VM's Network Security Group must also allow inbound 80 and 443.
> Docker: published container ports bypass UFW. Uptime Kuma is bound to `127.0.0.1` for that reason; don't run the repo's `docker-compose.yml` (port 8080) on the VPS.

**Demo evidence:** `sudo ufw status verbose`, `sudo fail2ban-client status sshd` (it will already list banned IPs after a day online), and `ssh -o PubkeyAuthentication=no user@host` showing `Permission denied (publickey)`.

## Rollback

```bash
sudo rm /etc/ssh/sshd_config.d/00-hardening.conf && sudo systemctl reload ssh
sudo ufw disable
sudo systemctl disable --now fail2ban
sudo a2disconf security-hardening && sudo rm /etc/php/*/apache2/conf.d/99-hardening.ini && sudo systemctl reload apache2
```
