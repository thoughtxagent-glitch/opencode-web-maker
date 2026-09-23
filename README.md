# 🚀 OpenCode `web.maker` (`web`) Custom Agent & Complete Blueprint

Welcome to the **`web.maker`** agent for OpenCode — the ultimate **Master Full-Stack Web Architect & Senior Design Engineer** agent.

When enabled, pressing **Tab** in OpenCode toggles between **`build`**, **`plan`**, and **`web`**!

---

## 🌟 Quick Installation into OpenCode

To install `web.maker` globally in your OpenCode environment:

```bash
mkdir -p ~/.config/opencode/agent
cp .opencode/agent/web.md ~/.config/opencode/agent/web.md
```

Then run `opencode` and hit **`Tab`** to switch to the **`web`** mode!

---

# 📚 COMPLETE 360° WEB ARCHITECTURE MANUAL & BLUEPRINT

`web.maker` operates under strict engineering and visual design guidelines. Zero AI-slop, 100% production-grade type-safe code.

---

## 🎨 1. VISUAL AESTHETICS & FRONTEND EXCELLENCE (Anti-AI-Slop Standard)

### 🚫 Banned AI-Slop Aesthetics
- **NO Default Indigo/Purple Gradients**: Banned generic AI gradient backgrounds.
- **NO Un-tweaked Inter Font**: Inter font polosan without custom `letter-spacing`, `font-weight` hierarchy, and proper font pairings is strictly prohibited.
- **NO Standard 3-Card Hero Layout**: Banned repetitive 3-box feature sections.

### ✨ Surface Archetype & Design Systems
- **Bento Grid 2.0 Layouts**: Modular, multi-aspect-ratio grids inspired by Vercel, Linear, Apple, and Notion.
- **Glassmorphism 2.0 & Dark Neobrutalism**: Multi-layered backdrop blurs (`backdrop-blur-md` to `xl`), hairline subtle borders (`border-white/10`), inset glow, crisp shadows, and tactical micro-badges.
- **OKLCH Color Space**: Perceptually uniform color palettes, rich saturation, and **100% WCAG AAA** contrast compliance.

### 🎭 Micro-Interactions & Creative Coding
- **Framer Motion**: Smooth page transitions, scroll animations, dynamic spring physics, and shared layout animations (`layoutId`).
- **Canvas Shaders & Particles**: Interactive background graphics via **p5.js**, **Three.js**, or native **WebGL shaders**.
- **Dynamic Interactive SVGs**: Dark-themed architecture diagrams with glowing animated path strokes.

### ⚛️ Modern Tech Stack Frontend
- **Frameworks**: Next.js 14/15 (App Router, Server Components, Server Actions), React 19, Vue/Nuxt 3, SvelteKit, Vite.
- **Styling**: Tailwind CSS v4, Radix UI Primitives, Shadcn/ui, CSS Modules.
- **State & Data**: Zustand, TanStack React Query, Redux Toolkit, Jotai.

---

## ⚡ 2. HIGH-PERFORMANCE & CLEAN BACKEND ARCHITECTURE

### 🧱 Modular Layered Architecture (Separation of Concerns)
Strict directory structure:
```text
src/
├── config/         # Environment variables, DB connections, CORS, Auth config
├── controllers/    # Request/Response handling (HTTP layer only)
├── services/       # Business logic layer
├── repositories/   # Direct Database Queries (ORM / Raw SQL)
├── middlewares/    # Auth check, Rate limiting, Error handling, Logging
├── schemas/        # Zod / TypeBox DTO validation schemas
├── routes/         # Endpoint route definitions
├── types/          # Shared TypeScript interfaces & types
└── utils/          # Logger (Pino/Winston), Helper functions
```
- **Controllers**: Only handle HTTP I/O.
- **Services**: Contain pure business logic.
- **Repositories**: Handle database interactions exclusively.

### 🛡️ End-to-End Type Safety & Data Integrity
- Complete schema validation using **Zod** or **TypeBox** for `req.body`, `req.query`, and `req.params`.
- Contract-first API development using **tRPC** or **OpenAPI / Swagger** generated clients.

### 🚀 Runtimes & Frameworks Supported
- **Node.js & Bun**: Fastify (high throughput), Express.js, NestJS (Enterprise Modular), Hono.
- **Python**: FastAPI (async, auto OpenAPI generation).
- **Go**: Fiber / Gin (microsecond performance).
- **Realtime & Streaming**: WebSockets (Socket.io / ws), Server-Sent Events (SSE), AI Response Streaming.

---

## 🗄️ 3. DATABASE ARCHITECTURE & OPTIMIZATION

- **Databases**: PostgreSQL, MySQL, SQLite, MongoDB, Redis.
- **ORMs & Query Builders**: Drizzle ORM, Prisma, Kysely, TypeORM.
- **Query & Storage Optimization**:
  - Proper index design (`B-Tree`, `GIN` for JSONB/Full-Text Search).
  - Advanced SQL: Window Functions, Common Table Expressions (CTEs), Subqueries.
  - Redis In-Memory Caching Strategy (Cache-Aside, Write-Through, TTL invalidation).
  - Database Migrations: Zero-downtime **Expand-Contract** pattern.

---

## 🛡️ 4. OWASP TOP 10 SECURITY HARDENING

- **Authentication & Authorization**:
  - JWT with **RS256 Asymmetric Key Rotation** (Private key signs on server, Public key verifies).
  - Session tokens stored exclusively in `HttpOnly`, `Secure`, `SameSite=Strict` Cookies.
  - OAuth2 integration (Google, GitHub), Auth.js / NextAuth, Clerk, Supabase Auth.
- **API Protection & Defense**:
  - **Helmet.js** security headers (`X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`).
  - **Rate Limiting**: Sliding window rate-limiting per IP/token using Redis.
  - **Input Sanitization**: Parameterized ORM queries (Zero SQL Injection) and XSS prevention.

---

## 🚀 5. DEVOPS, TESTING & PERFORMANCE OPTIMIZATION

### 📊 Core Web Vitals Enforcement
- **LCP (Largest Contentful Paint)**: `< 1.2s` via image optimization & dynamic code splitting.
- **CLS (Cumulative Layout Shift)**: `0.00` via reserved layout aspect ratios & skeleton loaders.
- **INP (Interaction to Next Paint)**: `< 50ms` via debounced handlers & non-blocking renders.

### 🧪 Automated Testing Suite
- **Unit & Integration**: Jest, Vitest, React Testing Library (RTL).
- **End-to-End (E2E)**: Playwright / Cypress.
- **Load Testing & Mocking**: MSW (Mock Service Worker), **k6** load testing scripts.

### 🐳 Containerization & Deployment
- Multi-stage `Dockerfile` (ultra-small runtime images ~50MB).
- `docker-compose.yml` (App + Database + Redis + Nginx Reverse Proxy).
- One-click deployment pipelines for Vercel, Cloudflare Workers, AWS, Netlify, or VPS Docker via GitHub Actions.

---

## 📋 6. STEP-BY-STEP WORKFLOW

```text
[ Phase 1: Planning ] ──> Define Architecture, Tech Stack & Design Tokens
         │
[ Phase 2: Backend ]  ──> DB Schema ➔ Migration ➔ Zod Validation ➔ API Routes ➔ Auth Middleware
         │
[ Phase 3: Frontend ] ──> Design System ➔ Bento Layout ➔ OKLCH Colors ➔ Hero Particle/Canvas ➔ Components
         │
[ Phase 4: Integrasi ]──> Type-safe Client ➔ State Mgmt (Zustand/Query) ➔ Micro-interactions
         │
[ Phase 5: Security ] ──> Helmet ➔ CORS ➔ Rate Limit ➔ HttpOnly Cookie Audit ➔ OWASP Check
         │
[ Phase 6: Launch ]   ──> Core Web Vitals Check ➔ Docker Build ➔ Deployment! 🚀
```

---
*Powered by Bxploit & OpenCode Architecture.*
