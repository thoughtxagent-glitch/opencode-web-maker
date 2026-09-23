# MASTER FULLSTACK WEB ARCHITECT & ANTI-GENERIC DESIGN PLAYBOOK 🔥
**Version:** 5.0.0-FINAL-SYNTHESIS  
**Author:** Bxploit Master Web Architect (Synthesized from All 14 Knowledge Modules)  
**Location:** `$BXPLOIT_ROOT/knowledge/master-web-architect.md`  

---

## 🚀 EXECUTIVE SUMMARY & PHILOSOPHY: THE ANTI-AI-SLOP MANIFESTO

Website modern sering terjebak dalam **"AI Slop Syndrome"**: visual seragam berbasis Tailwind default, Inter font tanpa tweaking letter-spacing, 3 feature card sejajar tanpa hierarki, gradient indigo/purple murahan, hero section melayang tanpa konsep surface archetype, database tanpa indexing, dan security yang dijadikan afterthought.

**Bxploit Fullstack Architecture Directives**:
1. **Surface Archetype First**: Tentukan jenis permukaan (`Monitor`, `Operate`, `Compare`, `Decide`) sebelum menyentuh CSS/HTML.
2. **Perceptually Uniform Color Space**: Gunakan OKLCH Color Space untuk jaminan kontras rasio minimal **7:1 (WCAG AAA)**.
3. **End-to-End Type Safety**: Zod validation di API Gateway → ORM type inference → Client Type-Safe (tRPC / OpenAPI).
4. **Database Performance by Default**: Index B-tree/GIN wajib di semua FK, kolom pencarian, dan filter `WHERE`.
5. **Hardened Security Core**: Dynamic JWT RS256 rotation, HTTP-only cookies, Helmet headers, dan Rate limiting berbasis Redis.
6. **Zero-Downtime Infrastructure**: Multi-stage Docker build, CI/CD pipeline, dan pola migrasi DB *Expand-Contract*.

---

## 📚 MASTER SYNTHESIS: 14 MODUL KNOWLEDGE BASE SYSTEM

```text
                               ┌─────────────────────────────────────────┐
                               │     WEBSITE-KNOWLEDGE-INDEX.md          │
                               │   (Master Navigation & Quick Matrix)    │
                               └────────────────────┬────────────────────┘
                                                    │
             ┌──────────────────────────────────────┼──────────────────────────────────────┐
             ▼                                      ▼                                      ▼
   ┌───────────────────┐                  ┌───────────────────┐                  ┌───────────────────┐
   │ FRONTEND ENGINE   │                  │  BACKEND & DATA   │                  │ DEVOPS & QUALITY  │
   ├───────────────────┤                  ├───────────────────┤                  ├───────────────────┤
   │ frontend-uiux     │                  │ backend-fullstack │                  │ devops-deployment │
   │ frontend-advanced │                  │ database-schema   │                  │ testing-perf      │
   │ creative-coding   │                  │ realtime-api      │                  │ performance-opt   │
   │                   │                  │ security-web      │                  │ architecture-pat  │
   │                   │                  │ payment-stripe    │                  │                   │
   └───────────────────┘                  └───────────────────┘                  └───────────────────┘
```

---

## 🛠️ CORE PILLARS & ARCHITECTURAL PATTERNS

### PILLAR 1: FRONTEND UI/UX & ANTI-GENERIC DESIGN
- **Surface Archetype System**:
  - *Monitor/Dashboard*: High data density, OKLCH high-contrast, tabular numbers (`font-variant-numeric: tabular-nums`).
  - *Operate/Control*: Micro-radii (`4px`), hard neobrutal contrast, status badges tactical.
  - *Decide/Learn*: Hero section dipadu kinetic typography, ambient WebGL noise canvas, live code/demo widgets.
- **Aesthetic Paradigms**:
  - *Dark Neobrutalism*: Charcoal base (`#090D16`), crisp border (`2px solid #30363d`), offset shadow (`4px 4px 0px oklch(0.7 0.25 190)`).
  - *Glassmorphic 2.0*: Inset specular highlight (`rgba(255,255,255,0.12)`), multi-layered backdrop blur.

### PILLAR 2: ADVANCED FRONTEND & CREATIVE CANVAS
- **React 18/19 & Next.js App Router**:
  - React Server Components (RSC) untuk zero-bundle server rendering.
  - Server Actions untuk form mutation type-safe dengan `revalidatePath`.
  - Concurrent features (`useTransition`, `useDeferredValue`) untuk UI ultra-smooth.
- **State Management**: Zustand untuk client global state (persisted) + TanStack Query v5 untuk server state caching & optimistic updates.
- **Creative Coding Integration**: p5.js particle physics vector background canvas & custom WebGL shaders.

### PILLAR 3: BACKEND ARCHITECTURE & REALTIME SYSTEMS
- **API Design**: Dual REST/GraphQL Gateway + internal tRPC end-to-end type safety.
- **Realtime Infrastructure**: WebSocket (Socket.io + Redis Adapter) untuk bidirectional chat/collaboration, SSE untuk server-to-client notifications, dan ReadableStream untuk AI response streaming.
- **Resilience**: Redis Token Bucket Rate Limiting (`100 req/min`), Circuit Breaker, dan centralized error handling.

### PILLAR 4: DATABASE & PERSISTENCE HARDENING
- **PostgreSQL Optimization**:
  - Primary Key: Internal `BIGSERIAL` + Public `UUID v7` / `ULID`.
  - Indexes: B-tree, Partial index, GIN index (JSONB/FTS), dan Covering index (`INCLUDE`).
  - Advanced Querying: CTEs recursive, Window functions (`ROW_NUMBER`, `LAG/LEAD`), dan Full-text search `tsvector`.
- **Redis Mastery**: Cache-aside pattern, sliding window rate limiter, distributed locking (Redlock), dan Pub/Sub.

### PILLAR 5: SECURITY & PAYMENT SYSTEMS
- **Security Hardening**:
  - OWASP Top 10 fixes lengkap (Broken Access Control, Injection, SSRF).
  - Asymmetric JWT RS256 dengan short-lived access token + Refresh token rotation & reuse detection di Redis.
  - Helmet security headers (CSP, HSTS, X-Frame-Options DENY, X-Content-Type-Options nosniff).
- **Stripe Payment Engine**:
  - Stripe Checkout (Hosted) & Stripe Elements (Custom UI).
  - Webhook verification dengan signature checking & DB event idempotency.
  - Subscription database schema & plan gating middleware/hooks.

### PILLAR 6: DEVOPS, TESTING & PERFORMANCE
- **DevOps & Infrastructure**:
  - Multi-stage Docker build (deps → builder → runner minimal alpine image).
  - Docker Compose dengan healthchecks untuk PostgreSQL & Redis.
  - GitHub Actions CI/CD (lint → test → build → push GHCR → deploy VPS via SSH).
  - Nginx Reverse Proxy dengan TLS 1.3, HSTS, dan HTTP/2.
- **Testing & Performance**:
  - Testing Trophy: Jest + React Testing Library (unit/component) + Playwright (E2E) + MSW (API mocking) + k6 (load test).
  - Core Web Vitals optimization: LCP < 2.5s, CLS < 0.1, INP < 200ms.
  - Image optimization (Next/Image WebP/AVIF) & Font subsetting (`display: swap`).

---

## 📋 PRE-PROJECT & PRE-LAUNCH CHECKLISTS

### Pre-Project Checklist (Sebelum Mulai Coding):
1. [x] Tentukan **Surface Archetype** (Monitor vs Operate vs Compare vs Decide).
2. [x] Tentukan **Tech Stack Framework** (lihat matrix di `architecture-patterns-mastery.md`).
3. [x] Setup struktur folder (Monorepo Turborepo atau Clean Single App).
4. [x] Konfigurasi environment variables dengan validasi Zod saat startup.
5. [x] Setup ESLint + Prettier + Husky pre-commit hooks.
6. [x] Rancang schema database & migrasi awal.

### Pre-Launch Checklist (Sebelum Deploy Production):
1. [x] Core Web Vitals teruji: LCP < 2.5s, CLS < 0.1, INP < 200ms.
2. [x] Security headers Helmet aktif (CSP, HSTS, X-Frame, X-Content-Type).
3. [x] Rate limiting aktif di semua public API endpoints.
4. [x] Indeks database terpasang pada semua Foreign Keys dan filter columns.
5. [x] Webhook Stripe terverifikasi dengan idempotency check.
6. [x] Pipeline CI/CD dan multi-stage Docker image siap.
7. [x] Error monitoring Sentry terhubung.

---

*Bxploit Master Web Architect Playbook Version 5.0.0 — Ultimate, Lethal, 100% Anti-Generic. No talk, all walk.*
