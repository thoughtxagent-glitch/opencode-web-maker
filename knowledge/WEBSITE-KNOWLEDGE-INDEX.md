# 📚 BXPLOIT WEBSITE KNOWLEDGE BASE — MASTER INDEX
**Version:** 3.0.0-COMPREHENSIVE  
**Last Updated:** Auto-managed by Bxploit Autonomous Swarm  
**Purpose:** Registry lengkap semua modul pengetahuan pembuatan website fullstack (Frontend, Backend, Database, Security, Realtime, Payment, Testing, DevOps, Performance). Baca file ini PERTAMA sebelum mulai membuat website apapun.

---

## 🗂️ DAFTAR MODUL KNOWLEDGE BASE (TOTAL: 12 MODUL KOMPREHENSIF)

| File | Topik / Cakupan Utamanya | Ukuran | Status |
|------|--------------------------|--------|--------|
| `master-web-architect.md` | Master index, philosophy anti-AI-slop, Surface Archetypes | ~6 KB | ✅ Ready |
| `frontend-uiux-mastery.md` | UI/UX visual, Bento Grid, Glassmorphism 2.0, OKLCH, WCAG AAA | ~12 KB | ✅ Ready |
| `frontend-advanced-mastery.md` | React 18/19, Next.js App Router, State Management (Zustand/Query), Animations | ~35 KB | ✅ Ready |
| `creative-coding-mastery.md` | p5.js, WebGL Shaders, Particle Systems, Interactive Architecture Diagrams | ~16 KB | ✅ Ready |
| `backend-fullstack-mastery.md` | Backend Architecture, REST/GraphQL debug, Sintesis 54 Design Systems | ~25 KB | ✅ Ready |
| `database-schema-sql-mastery.md` | PostgreSQL Deep Dive, Indexing (B-Tree/GIN), CTEs, Window Functions, Redis | ~25 KB | ✅ Ready |
| `realtime-api-patterns-mastery.md` | WebSocket, SSE, AI Response Streaming, tRPC, Pagination, Caching, Errors | ~23 KB | ✅ Ready |
| `security-web-mastery.md` | OWASP Top 10 Fixes, JWT RS256 rotation, Helmet, Rate Limiting, File Upload | ~20 KB | ✅ Ready |
| `payment-stripe-mastery.md` | Stripe Checkout & Elements, Webhook verification, Billing DB, Plan Gating | ~18 KB | ✅ Ready |
| `testing-performance-mastery.md` | Jest, React Testing Library, Playwright E2E, MSW, k6 Load Testing | ~55 KB | ✅ Ready |
| `performance-optimization-mastery.md` | Core Web Vitals (LCP, CLS, INP), Bundle Analysis, Image/Font Opt, Next Cache | ~18 KB | ✅ Ready |
| `architecture-patterns-mastery.md` | Tech Stack Decision Framework, Monorepo, DDD, Starter Boilerplates | ~58 KB | ✅ Ready |

---

## 🚀 QUICK START MATRIX (PILIH PROJECT TYPE → BACA MODUL SPESIFIK)

```text
PROJECT TYPE             → WAJIB BACA MODUL INI SEBELUM CODING
───────────────────────────────────────────────────────────────────────────────────────────
1. SaaS Full-Stack App   → architecture-patterns + database-schema-sql + payment-stripe + security-web
2. High-Traffic API      → backend-fullstack + realtime-api-patterns + database-schema-sql + performance-optimization
3. E-commerce Website    → payment-stripe + database-schema-sql + performance-optimization + security-web
4. Real-time & Chat App  → realtime-api-patterns + database-schema-sql + frontend-advanced
5. Landing Page / Brand  → frontend-uiux + creative-coding + performance-optimization
6. Dashboard / Admin     → frontend-uiux + frontend-advanced + architecture-patterns
```

---

## 💎 CORE PHILOSOPHY & MANDATORY DIRECTIVES (Anti-AI-Slop)

1. **Surface Archetype System**: Selalu kunci jenis surface (`Monitor`, `Operate`, `Compare`, `Decide`) sebelum menulis CSS/HTML.
2. **Strict Color Standard**: Gunakan OKLCH Color Space untuk jaminan uniform lightness dan kontras rasio minimal **7:1 (WCAG AAA)**.
3. **Database Performance**: Buat indeks B-tree/GIN pada semua kolom Foreign Key, search query, dan filter `WHERE` sebelum deploy.
4. **End-to-End Type Safety**: Zod validation di API Gateway → ORM Type Inference → Client Type-Safe (tRPC / OpenAPI).
5. **Security First**: Dynamic JWT RS256 rotation, HTTP-only cookies, Strict CSP, Helmet, Rate limiting di Redis — bukan afterthought.
6. **Robust Realtime**: Bedah penggunaan WebSocket vs SSE vs Streaming response sesuai kebutuhan spesifik data flow.
7. **Zero-Downtime Releases**: Pola migrasi database *Expand-Contract* untuk menjaga ketersediaan 99.99%.

---

## 📖 COMMAND BACA KNOWLEDGE BASE SEBELUM BUAT WEBSITE

Ketika kamu hendak membuat website baru, eksekusi command berikut untuk memuat konteks secara otomatis:

```bash
# Command otomatis load master index & architect playbook:
cat $BXPLOIT_ROOT/knowledge/WEBSITE-KNOWLEDGE-INDEX.md
cat $BXPLOIT_ROOT/knowledge/master-web-architect.md

# Load modul spesifik sesuai tipe proyek (contoh SaaS):
cat $BXPLOIT_ROOT/knowledge/architecture-patterns-mastery.md
cat $BXPLOIT_ROOT/knowledge/database-schema-sql-mastery.md
```

---
*Bxploit Unified Fullstack Architecture Knowledge Registry — Complete & Verified.*
