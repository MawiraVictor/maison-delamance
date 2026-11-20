# SSL Labs A+ and security headers (course sections 8/9)

All in `shop.piuskl.me.conf`, so the GitHub deploy installs it and only
reloads Apache if `apachectl configtest` passes.

- TLS 1.2 and 1.3 only, forward-secret AEAD ciphers (Mozilla intermediate)
- HSTS for one year (required for A+)
- OCSP stapling
- Headers: Content-Security-Policy, X-Frame-Options, X-Content-Type-Options,
  Referrer-Policy, Permissions-Policy, Cross-Origin-Opener-Policy; X-Powered-By removed

The CSP allows only this site plus Google Fonts, the only third party the pages
load, with inline styles allowed for the `style=""` attributes. If something
stops loading, the browser console names the blocked URL.

## Check

- https://www.ssllabs.com/ssltest/analyze.html?d=shop.piuskl.me (target A+)
- https://securityheaders.com/?q=shop.piuskl.me (target A)

## Rollback

`git revert` this branch's merge commit and push; the deploy reinstalls the previous vhost.
