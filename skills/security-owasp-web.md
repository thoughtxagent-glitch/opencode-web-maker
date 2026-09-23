# 🛡️ SKILL: OWASP Top 10 Web Security Hardening

## Authentication & Session Security
- JWT RS256: Asymmetric key rotation (Private key signing on server, Public key verification).
- HttpOnly Cookies: Access & Refresh tokens stored in `HttpOnly, Secure, SameSite=Strict` cookies (Zero XSS token theft).
- Password Hashing: Argon2id or Bcrypt with minimum 12 rounds.

## API & Defense Rules
- Helmet Security Headers: CSP (`Content-Security-Policy`), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`.
- Rate Limiting: Sliding window algorithm via Redis per IP/Token to prevent DDoS & Brute-force attacks.
- Input Sanitization: Zod schema parsing on all request inputs to prevent SQL Injection & Stored XSS.
