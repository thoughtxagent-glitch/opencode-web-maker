# 🔐 WEB SECURITY MASTERY — Bxploit Knowledge Base
**Version:** 1.0.0 | **Category:** Security Engineering for Web Development

---

## 1. OWASP TOP 10 (2021) — DEFINISI + FIX LENGKAP

### A01 — Broken Access Control
**Apa itu**: User bisa akses resource yang bukan haknya (horizontal/vertical privilege escalation).
```typescript
// ❌ SALAH: Tidak cek ownership
app.get('/api/documents/:id', auth, async (req, res) => {
  const doc = await db.document.findById(req.params.id); // bisa akses punya orang lain!
  return res.json(doc);
});

// ✅ BENAR: Cek ownership + role
app.get('/api/documents/:id', auth, async (req, res) => {
  const doc = await db.document.findFirst({
    where: { id: req.params.id, userId: req.user.id } // hanya punya user sendiri
  });
  if (!doc) return res.status(403).json({ error: 'Forbidden' });
  return res.json(doc);
});
```
**Fix**: Row-level ownership checks, RBAC middleware, deny-by-default policy.

### A02 — Cryptographic Failures
**Apa itu**: Data sensitif tidak dienkripsi, pakai algoritma lemah, atau salah implementasi.
```typescript
// ❌ SALAH: Password plaintext atau MD5
const hash = md5(password); // JANGAN!

// ✅ BENAR: bcrypt dengan salt rounds minimum 12
import bcrypt from 'bcrypt';
const SALT_ROUNDS = 12;
const hash = await bcrypt.hash(password, SALT_ROUNDS);
const isValid = await bcrypt.compare(inputPassword, hash);

// ✅ BENAR: Enkripsi data sensitif di DB dengan AES-256-GCM
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';
function encrypt(text: string, key: Buffer): { encrypted: string; iv: string; tag: string } {
  const iv = randomBytes(16);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return { encrypted: encrypted.toString('hex'), iv: iv.toString('hex'), tag: tag.toString('hex') };
}
```
**Fix**: bcrypt/Argon2 untuk passwords, AES-256-GCM untuk data sensitif, HTTPS only (HSTS), TLS 1.2+ minimum.

### A03 — Injection (SQL, NoSQL, Command, LDAP)
**Apa itu**: User input dieksekusi sebagai code/query.
```typescript
// ❌ SALAH: String concatenation di query
const users = await db.query(`SELECT * FROM users WHERE email = '${userInput}'`);

// ✅ BENAR: Parameterized query
const users = await db.query('SELECT * FROM users WHERE email = $1', [userInput]);

// ✅ BENAR: ORM (Drizzle/Prisma auto-parameterize)
const users = await db.select().from(usersTable).where(eq(usersTable.email, userInput));

// ❌ SALAH: Command injection
exec(`ls ${userInput}`); // bisa inject: ; rm -rf /

// ✅ BENAR: Validasi strict + array args
execFile('ls', [sanitizedPath]); // tidak ada shell interpolation
```
**Fix**: Parameterized queries 100%, ORM, input whitelist validation (Zod), escaping.

### A04 — Insecure Design
**Apa itu**: Arsitektur yang tidak memperhitungkan security dari awal.
- Tidak ada rate limiting pada endpoint login → brute force
- Reset password tidak expire → account takeover
- Upload file tanpa validasi → malware upload

**Fix**: Threat modeling di design phase, security requirements, defense-in-depth.

### A05 — Security Misconfiguration
```bash
# ❌ Default credentials
admin:admin, root:root, postgres:postgres

# ❌ Debug mode di production
NODE_ENV=development  # JANGAN di prod!
DEBUG=*               # JANGAN di prod!

# ❌ Stack traces exposed di error responses
{ "error": "Error at /app/src/db/user.ts:42 - relation users does not exist" }

# ✅ Production error response
{ "error": "Internal server error", "requestId": "req-abc123" }
```
**Fix**: Environment-specific configs, disable debug production, custom error handlers, `npm audit`.

### A06 — Vulnerable & Outdated Components
```bash
# Audit dependencies
npm audit
npm audit fix

# Snyk scan
snyk test

# Dependabot di GitHub — auto PR untuk security updates
# .github/dependabot.yml
```

### A07 — Identification & Authentication Failures
```typescript
// ❌ Weak session management
res.cookie('session', userId.toString()); // predictable!

// ✅ BENAR: JWT HTTP-only cookie dengan expiry
const token = jwt.sign({ sub: userId, jti: randomUUID() }, secret, { expiresIn: '15m' });
res.cookie('access_token', token, {
  httpOnly: true,    // tidak bisa diakses JS (anti-XSS)
  secure: true,      // HTTPS only
  sameSite: 'lax',   // anti-CSRF
  maxAge: 15 * 60 * 1000
});

// ✅ Rate limit login endpoint
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 menit
  max: 10, // 10 attempts per window
  skipSuccessfulRequests: true,
  standardHeaders: true,
  message: { error: 'Too many login attempts, try again later' }
});
app.post('/api/auth/login', loginLimiter, loginHandler);

// ✅ Lockout setelah N failed attempts
// Track failed attempts di Redis, lockout 30 menit setelah 5 gagal
```

### A08 — Software & Data Integrity Failures
```typescript
// ❌ Deserialize untrusted data tanpa validasi
const data = JSON.parse(userInput); // berbahaya jika pakai eval-based deserializer

// ✅ Validate dengan Zod setelah parse
const schema = z.object({ name: z.string(), age: z.number().int().positive() });
const data = schema.parse(JSON.parse(userInput)); // throw jika invalid

// ✅ Verify webhook signatures (Stripe, GitHub, etc.)
import { createHmac } from 'crypto';
function verifyWebhookSignature(payload: string, signature: string, secret: string): boolean {
  const expectedSig = createHmac('sha256', secret).update(payload).digest('hex');
  const sigBuffer = Buffer.from(signature, 'hex');
  const expBuffer = Buffer.from(expectedSig, 'hex');
  if (sigBuffer.length !== expBuffer.length) return false;
  return timingSafeEqual(sigBuffer, expBuffer); // constant-time comparison!
}
```

### A09 — Security Logging & Monitoring Failures
```typescript
// ✅ Log security events
logger.warn({ event: 'login_failed', email: req.body.email, ip: req.ip, ua: req.headers['user-agent'] });
logger.info({ event: 'login_success', userId: user.id, ip: req.ip });
logger.error({ event: 'unauthorized_access', userId: req.user?.id, path: req.path, ip: req.ip });
logger.warn({ event: 'rate_limit_hit', ip: req.ip, path: req.path });

// ✅ Sentry untuk error alerting
import * as Sentry from '@sentry/node';
Sentry.captureException(error, { user: { id: req.user?.id, email: req.user?.email } });
```

### A10 — Server-Side Request Forgery (SSRF)
```typescript
// ❌ Fetch URL dari user input langsung
const response = await fetch(req.body.url); // bisa akses internal: http://169.254.169.254/

// ✅ Whitelist allowed domains
const ALLOWED_DOMAINS = ['api.github.com', 'api.stripe.com'];
function validateUrl(url: string): boolean {
  const parsed = new URL(url);
  if (!['http:', 'https:'].includes(parsed.protocol)) return false;
  if (!ALLOWED_DOMAINS.some(d => parsed.hostname === d || parsed.hostname.endsWith(`.${d}`))) return false;
  // Block private IP ranges
  const privateRanges = [/^127\./, /^10\./, /^172\.(1[6-9]|2\d|3[01])\./, /^192\.168\./];
  if (privateRanges.some(r => r.test(parsed.hostname))) return false;
  return true;
}
```

---

## 2. SECURITY HEADERS STACK LENGKAP

```typescript
// Helmet.js full config untuk Express
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'nonce-{NONCE}'"], // gunakan nonce, bukan 'unsafe-inline'
      styleSrc: ["'self'", "'unsafe-inline'"],  // Tailwind butuh ini atau pakai nonce
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", 'https://api.yourdomain.com'],
      fontSrc: ["'self'", 'https://fonts.gstatic.com'],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginResourcePolicy: { policy: 'same-site' },
  dnsPrefetchControl: { allow: false },
  frameguard: { action: 'deny' },           // X-Frame-Options: DENY
  hidePoweredBy: true,                       // Remove X-Powered-By
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true }, // HSTS 1 year
  ieNoOpen: true,
  noSniff: true,                             // X-Content-Type-Options: nosniff
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  xssFilter: true,
}));
```

**Next.js headers config** (`next.config.js`):
```javascript
const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'off' },
  { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains; preload' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
];

module.exports = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};
```

---

## 3. AUTHENTICATION HARDENING

### JWT Security Best Practices
```typescript
import jwt from 'jsonwebtoken';
import { createPrivateKey, createPublicKey } from 'crypto';

// RS256 (asymmetric) lebih aman dari HS256 untuk distributed systems
const privateKey = createPrivateKey(process.env.JWT_PRIVATE_KEY!);
const publicKey = createPublicKey(process.env.JWT_PUBLIC_KEY!);

// Issue token
function issueAccessToken(userId: string): string {
  return jwt.sign(
    { 
      sub: userId,
      jti: randomUUID(),     // unique token ID (untuk blacklisting)
      iss: 'your-app.com',   // issuer
      aud: 'your-app.com',   // audience
    },
    privateKey,
    { algorithm: 'RS256', expiresIn: '15m' }
  );
}

// Verify token
function verifyAccessToken(token: string): jwt.JwtPayload {
  return jwt.verify(token, publicKey, {
    algorithms: ['RS256'],
    issuer: 'your-app.com',
    audience: 'your-app.com',
  }) as jwt.JwtPayload;
}
```

### Refresh Token Rotation + Reuse Detection
```typescript
// Redis key: refresh_token:{token_hash} → { userId, family, used }
// Family = UUID dibuat saat login pertama. Semua token dalam keluarga punya family sama.

async function rotateRefreshToken(oldToken: string): Promise<{ accessToken: string; refreshToken: string }> {
  const tokenHash = sha256(oldToken);
  const stored = await redis.get(`refresh_token:${tokenHash}`);
  
  if (!stored) throw new UnauthorizedError('Invalid refresh token');
  
  const { userId, family, used } = JSON.parse(stored);
  
  // Reuse detection: jika token sudah pernah dipakai
  if (used) {
    // Kemungkinan token dicuri! Invalidate seluruh family
    await redis.del(`refresh_family:${family}`); // hapus semua token dalam family
    throw new UnauthorizedError('Refresh token reuse detected — please login again');
  }
  
  // Mark as used
  await redis.set(`refresh_token:${tokenHash}`, JSON.stringify({ userId, family, used: true }), 'EX', 3600);
  
  // Issue new tokens
  const newRefreshToken = randomBytes(64).toString('hex');
  const newTokenHash = sha256(newRefreshToken);
  await redis.set(`refresh_token:${newTokenHash}`, JSON.stringify({ userId, family, used: false }), 'EX', 7 * 24 * 3600);
  
  return {
    accessToken: issueAccessToken(userId),
    refreshToken: newRefreshToken,
  };
}
```

---

## 4. INPUT VALIDATION & SANITIZATION

```typescript
import { z } from 'zod';
import DOMPurify from 'isomorphic-dompurify';
import validator from 'validator';

// Zod schema dengan custom refinements
const userRegistrationSchema = z.object({
  email: z.string().email().toLowerCase().trim(),
  password: z.string()
    .min(8)
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[a-z]/, 'Must contain lowercase')
    .regex(/[0-9]/, 'Must contain number')
    .regex(/[^A-Za-z0-9]/, 'Must contain special character'),
  username: z.string()
    .min(3).max(30)
    .regex(/^[a-zA-Z0-9_-]+$/, 'Only alphanumeric, dash, underscore')
    .trim(),
  bio: z.string().max(500).optional().transform(v => v ? DOMPurify.sanitize(v) : v), // sanitize HTML
  website: z.string().url().optional().refine(
    url => !url || validator.isURL(url, { protocols: ['http', 'https'], require_protocol: true }),
    'Invalid URL'
  ),
});

// Middleware validasi
function validateBody<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return res.status(422).json({
        success: false,
        error: 'Validation failed',
        details: result.error.flatten().fieldErrors,
      });
    }
    req.body = result.data; // Replace dengan data yang sudah di-sanitize
    next();
  };
}
```

---

## 5. RATE LIMITING PATTERNS

```typescript
import { rateLimit } from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL!);
const redisStore = new RedisStore({ sendCommand: (...args) => redis.call(...args) });

// Global rate limit
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: redisStore,
  keyGenerator: (req) => req.ip ?? 'unknown',
});

// Strict limit untuk auth endpoints
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  skipSuccessfulRequests: true,
  store: redisStore,
  keyGenerator: (req) => `auth:${req.ip}`,
  handler: (req, res) => res.status(429).json({
    error: 'Too many authentication attempts. Please try again after 15 minutes.',
    retryAfter: Math.ceil(req.rateLimit.resetTime?.getTime()! / 1000 - Date.now() / 1000),
  }),
});

// Per-user API rate limit (setelah authenticated)
export const userApiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 menit
  max: 100,
  store: redisStore,
  keyGenerator: (req) => `user:${req.user?.id}`,
});
```

---

## 6. FILE UPLOAD SECURITY

```typescript
import multer from 'multer';
import path from 'path';
import { createReadStream } from 'fs';
import fileType from 'file-type';

// Allowed MIME types dan extensions
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif']);
const ALLOWED_DOC_TYPES = new Set(['application/pdf', 'text/plain']);
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

// Multer memory storage (tidak simpan ke disk dulu)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE, files: 1 },
  fileFilter: (req, file, cb) => {
    // 1. Check MIME type dari header (bisa dipalsukan)
    if (!ALLOWED_IMAGE_TYPES.has(file.mimetype) && !ALLOWED_DOC_TYPES.has(file.mimetype)) {
      return cb(new Error('File type not allowed'));
    }
    cb(null, true);
  },
});

// Verifikasi magic bytes SETELAH upload (reliable)
async function verifyFileMagicBytes(buffer: Buffer): Promise<string> {
  const detected = await fileType.fromBuffer(buffer);
  if (!detected) throw new Error('Cannot determine file type');
  if (!ALLOWED_IMAGE_TYPES.has(detected.mime) && !ALLOWED_DOC_TYPES.has(detected.mime)) {
    throw new Error(`File type ${detected.mime} not allowed`);
  }
  return detected.mime;
}

// Upload ke S3 dengan nama file random (jangan pakai nama asli user!)
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
const s3 = new S3Client({ region: process.env.AWS_REGION });

async function uploadToS3(buffer: Buffer, mimeType: string, folder: string): Promise<string> {
  const ext = mimeType.split('/')[1];
  const filename = `${folder}/${randomUUID()}.${ext}`; // random UUID, bukan nama user
  
  await s3.send(new PutObjectCommand({
    Bucket: process.env.S3_BUCKET!,
    Key: filename,
    Body: buffer,
    ContentType: mimeType,
    ServerSideEncryption: 'AES256',
    // Tidak ada ACL public — akses via signed URL saja!
  }));
  
  return filename;
}
```

---

## 7. CORS CONFIGURATION

```typescript
import cors from 'cors';

const ALLOWED_ORIGINS = [
  'https://yourdomain.com',
  'https://www.yourdomain.com',
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : null,
].filter(Boolean) as string[];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, same-origin)
    if (!origin) return callback(null, true);
    if (ALLOWED_ORIGINS.includes(origin)) return callback(null, true);
    callback(new Error(`CORS policy: ${origin} not allowed`));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  credentials: true, // allow cookies
  maxAge: 86400,     // preflight cache 24 jam
}));
```

---

## 8. SECRETS MANAGEMENT

```typescript
// ✅ Validasi semua env variables saat startup dengan Zod
import { z } from 'zod';

const envSchema = z.object({
  // Database
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  
  // Auth
  JWT_PRIVATE_KEY: z.string().min(100),
  JWT_PUBLIC_KEY: z.string().min(100),
  SESSION_SECRET: z.string().min(32),
  
  // External services
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_WEBHOOK_SECRET: z.string().startsWith('whsec_'),
  RESEND_API_KEY: z.string(),
  S3_BUCKET: z.string(),
  AWS_REGION: z.string(),
  
  // App
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']),
  APP_URL: z.string().url(),
});

// Parse & export — app akan crash di startup jika ada env yang missing/invalid
export const env = envSchema.parse(process.env);
```

**Rules for secrets**:
- Never commit to Git — gunakan `.gitignore`, `.env.example` hanya untuk reference tanpa values
- Rotate credentials setiap 90 hari (atau immediately jika leak suspected)
- Gunakan secret manager: Doppler, Infisical, HashiCorp Vault, AWS Secrets Manager
- Principle of least privilege: setiap service hanya dapat credentials yang dibutuhkan

---

## 9. DEPENDENCY SECURITY

```bash
# Check vulnerabilities
npm audit
npm audit fix        # auto fix low-risk
npm audit fix --force # force fix (bisa breaking change)

# Snyk (lebih detail dari npm audit)
snyk test
snyk monitor         # ongoing monitoring

# Check outdated packages
npm outdated

# GitHub Dependabot — setup di .github/dependabot.yml:
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
    reviewers:
      - your-github-username
```

---

## 10. SECURITY CHECKLIST PRE-LAUNCH

### Authentication
- [ ] Passwords di-hash dengan bcrypt/Argon2 (cost factor ≥ 12)
- [ ] JWT menggunakan RS256, bukan HS256
- [ ] Access token expiry ≤ 15 menit
- [ ] Refresh token rotation dengan reuse detection
- [ ] HTTP-only cookies (bukan localStorage)
- [ ] Rate limiting pada login/register/forgot-password
- [ ] Account lockout setelah N failed attempts

### API Security
- [ ] Semua input di-validate dengan Zod
- [ ] Parameterized queries (zero string concatenation di SQL)
- [ ] CORS whitelist hanya origin yang dikenal
- [ ] Rate limiting global + per-endpoint
- [ ] API keys di-hash sebelum disimpan di DB
- [ ] Webhook signatures di-verify

### Infrastructure
- [ ] HTTPS everywhere, HTTP redirect ke HTTPS
- [ ] HSTS header dengan preload
- [ ] CSP header (no unsafe-inline untuk scripts)
- [ ] X-Frame-Options: DENY
- [ ] X-Content-Type-Options: nosniff
- [ ] Database tidak exposed ke internet publik (dalam VPC)
- [ ] DB credentials: principle of least privilege
- [ ] Backup terenkripsi dan ter-test (restore drill)

### Code
- [ ] `npm audit` clean (0 high/critical vulnerabilities)
- [ ] Secrets tidak ada di source code (git-secrets scan)
- [ ] Debug mode disabled di production
- [ ] Stack traces tidak exposed ke API responses
- [ ] Logging security events (login attempts, permission errors)
- [ ] Sentry atau error monitoring aktif

---

*Bxploit Security Mastery — Lock it down before they come for it. No cap. 🔒*
