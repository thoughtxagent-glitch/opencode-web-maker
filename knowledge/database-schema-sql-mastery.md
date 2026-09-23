# 🗄️ DATABASE SCHEMA DESIGN & SQL MASTERY — Bxploit Knowledge Base
**Version:** 1.0.0 | **Category:** Database Engineering

---

## 1. SCHEMA DESIGN PRINCIPLES

### Normalisasi vs Denormalisasi Decision Tree
```
NORMALISASI (3NF) ketika:
  ✅ Data sering di-update (consistency kritis)
  ✅ Storage cost is concern
  ✅ Complex relationships (many-to-many)
  ✅ OLTP workloads (INSERT/UPDATE/DELETE heavy)

DENORMALISASI ketika:
  ✅ Read-heavy workloads (dashboard, reports)
  ✅ JOIN terlalu mahal (millions of rows)
  ✅ Specific query pattern sudah jelas & stabil
  ✅ OLAP/analytics workloads
  ⚠️ Trade-off: update anomaly risk, data inconsistency
```

### Primary Key Strategy
```sql
-- UUID vs BIGSERIAL trade-offs:

-- BIGSERIAL (auto-increment integer)
id BIGSERIAL PRIMARY KEY
-- ✅ Compact (8 bytes), sortable, B-tree friendly
-- ✅ Readable (debugging lebih mudah)
-- ❌ Sequential = guessable (security concern untuk public IDs)
-- ❌ Distributed system: conflict risk

-- UUID v4 (random)
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
-- ✅ Global unique, non-guessable
-- ❌ 16 bytes, random = B-tree fragmentation, poor locality
-- ❌ Not time-sortable

-- UUID v7 (time-ordered) — RECOMMENDED untuk most cases
id UUID PRIMARY KEY DEFAULT gen_ulid() -- atau uuid7() extension
-- ✅ Time-ordered (monotonic) = B-tree friendly
-- ✅ Global unique, 48-bit timestamp prefix
-- ✅ Non-guessable tapi sortable by creation time

-- ULID (alternative to UUID v7)
-- 26 char Crockford base32: 01ARZ3NDEKTSV4RRFFQ69G5FAV
-- ✅ URL-safe, lexicographically sortable, case-insensitive

-- PATTERN: Internal PK = BIGSERIAL, Public ID = separate UUID/ULID column
CREATE TABLE products (
  id          BIGSERIAL PRIMARY KEY,  -- internal foreign keys
  public_id   UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE, -- exposed to API/URLs
  name        TEXT NOT NULL,
  ...
);
-- GET /api/products/01ARZ3... → lookup by public_id, bukan id
```

---

## 2. COMMON SCHEMA PATTERNS

### Users & Auth Schema
```sql
CREATE TABLE users (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  email               TEXT NOT NULL UNIQUE,
  email_verified      BOOLEAN NOT NULL DEFAULT false,
  email_verified_at   TIMESTAMPTZ,
  name                TEXT,
  avatar_url          TEXT,
  
  -- Auth
  password_hash       TEXT,              -- nullable: bisa OAuth-only
  stripe_customer_id  TEXT UNIQUE,
  
  -- Status
  role                TEXT NOT NULL DEFAULT 'user', -- 'user' | 'admin' | 'moderator'
  is_active           BOOLEAN NOT NULL DEFAULT true,
  banned_at           TIMESTAMPTZ,
  ban_reason          TEXT,
  
  -- Metadata
  last_seen_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_users_email ON users(lower(email)); -- case-insensitive unique
CREATE INDEX idx_users_public_id ON users(public_id);
CREATE INDEX idx_users_stripe_customer_id ON users(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;

-- OAuth accounts (multiple providers per user)
CREATE TABLE oauth_accounts (
  id            BIGSERIAL PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider      TEXT NOT NULL,         -- 'google' | 'github' | 'discord'
  provider_id   TEXT NOT NULL,         -- provider's user ID
  access_token  TEXT,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE(provider, provider_id)
);

-- Sessions (untuk database session strategy)
CREATE TABLE sessions (
  id          TEXT PRIMARY KEY,  -- session token hash
  user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address  INET,
  user_agent  TEXT
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at); -- for cleanup job

-- Email verification tokens
CREATE TABLE email_verification_tokens (
  token       TEXT PRIMARY KEY,       -- hashed token
  user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### SaaS Multi-tenant Schema (Row-Level Isolation)
```sql
-- Organizations/Workspaces
CREATE TABLE organizations (
  id          BIGSERIAL PRIMARY KEY,
  public_id   UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  slug        TEXT NOT NULL UNIQUE,   -- URL slug: /orgs/acme-corp
  name        TEXT NOT NULL,
  logo_url    TEXT,
  plan_id     BIGINT REFERENCES plans(id),
  
  -- Billing
  stripe_customer_id TEXT UNIQUE,
  
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_organizations_slug ON organizations(lower(slug));

-- Organization Members
CREATE TABLE organization_members (
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role            TEXT NOT NULL DEFAULT 'member', -- 'owner' | 'admin' | 'member' | 'viewer'
  invited_by      BIGINT REFERENCES users(id),
  accepted_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  PRIMARY KEY (organization_id, user_id)
);

-- ALL tenant-specific tables WAJIB punya organization_id column + index
CREATE TABLE projects (
  id              BIGSERIAL PRIMARY KEY,
  public_id       UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  created_by      BIGINT NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_projects_organization_id ON projects(organization_id);
-- ↑ WAJIB: semua query pasti filter by organization_id

-- Row Level Security (RLS) untuk PostgreSQL
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Policy: user hanya bisa akses projects dari org mereka
CREATE POLICY projects_org_isolation ON projects
  USING (
    organization_id IN (
      SELECT organization_id FROM organization_members
      WHERE user_id = current_setting('app.current_user_id')::BIGINT
    )
  );

-- Set di application layer sebelum query:
-- SET LOCAL app.current_user_id = '123';
```

### Blog/CMS Schema
```sql
CREATE TABLE posts (
  id              BIGSERIAL PRIMARY KEY,
  public_id       UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  slug            TEXT NOT NULL UNIQUE,
  title           TEXT NOT NULL,
  excerpt         TEXT,
  content         TEXT NOT NULL,         -- Markdown atau HTML
  content_json    JSONB,                 -- Tiptap/ProseMirror JSON (optional)
  cover_image_url TEXT,
  author_id       BIGINT NOT NULL REFERENCES users(id),
  
  -- Status & publishing
  status          TEXT NOT NULL DEFAULT 'draft', -- 'draft' | 'published' | 'archived'
  published_at    TIMESTAMPTZ,
  
  -- SEO
  seo_title       TEXT,
  seo_description TEXT,
  og_image_url    TEXT,
  
  -- Stats (denormalized untuk performance)
  view_count      INTEGER NOT NULL DEFAULT 0,
  like_count      INTEGER NOT NULL DEFAULT 0,
  comment_count   INTEGER NOT NULL DEFAULT 0,
  
  -- Soft delete
  deleted_at      TIMESTAMPTZ,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_posts_slug ON posts(lower(slug));
CREATE INDEX idx_posts_status_published ON posts(status, published_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_posts_author_id ON posts(author_id);

-- Full-text search index
CREATE INDEX idx_posts_search ON posts USING GIN(
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(excerpt, '') || ' ' || coalesce(content, ''))
);

-- Tags (Many-to-Many)
CREATE TABLE tags (
  id    BIGSERIAL PRIMARY KEY,
  slug  TEXT NOT NULL UNIQUE,
  name  TEXT NOT NULL,
  color TEXT DEFAULT '#6366f1'
);

CREATE TABLE post_tags (
  post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  tag_id  BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, tag_id)
);

CREATE INDEX idx_post_tags_tag_id ON post_tags(tag_id); -- untuk filter by tag
```

### E-commerce Schema
```sql
-- Products dengan inventory
CREATE TABLE products (
  id              BIGSERIAL PRIMARY KEY,
  public_id       UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  sku             TEXT NOT NULL UNIQUE,
  name            TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,
  description     TEXT,
  price_amount    INTEGER NOT NULL,    -- dalam cents (1000 = $10.00)
  compare_price   INTEGER,             -- original price untuk diskon
  currency        TEXT NOT NULL DEFAULT 'usd',
  category_id     BIGINT REFERENCES categories(id),
  
  -- Inventory
  track_inventory BOOLEAN NOT NULL DEFAULT true,
  stock_quantity  INTEGER NOT NULL DEFAULT 0,
  low_stock_alert INTEGER DEFAULT 10,
  
  -- Status
  status          TEXT NOT NULL DEFAULT 'draft', -- 'draft' | 'active' | 'archived'
  
  -- Search
  search_vector   TSVECTOR GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))
  ) STORED,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_search ON products USING GIN(search_vector);
CREATE INDEX idx_products_category_status ON products(category_id, status) WHERE status = 'active';
CREATE INDEX idx_products_slug ON products(slug);

-- Orders
CREATE TABLE orders (
  id              BIGSERIAL PRIMARY KEY,
  public_id       UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  order_number    TEXT NOT NULL UNIQUE DEFAULT ('ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('order_seq')::text, 6, '0')),
  user_id         BIGINT REFERENCES users(id),  -- nullable: guest checkout
  email           TEXT NOT NULL,                -- denorm untuk guest orders
  
  -- Amounts (semua dalam cents)
  subtotal_amount INTEGER NOT NULL,
  discount_amount INTEGER NOT NULL DEFAULT 0,
  tax_amount      INTEGER NOT NULL DEFAULT 0,
  shipping_amount INTEGER NOT NULL DEFAULT 0,
  total_amount    INTEGER NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'usd',
  
  -- Status
  status          TEXT NOT NULL DEFAULT 'pending',
  -- 'pending' → 'confirmed' → 'processing' → 'shipped' → 'delivered' | 'canceled' | 'refunded'
  
  -- Payment
  stripe_payment_intent_id TEXT UNIQUE,
  stripe_charge_id          TEXT,
  paid_at                   TIMESTAMPTZ,
  
  -- Shipping
  shipping_address JSONB NOT NULL,
  
  -- Metadata
  notes           TEXT,
  metadata        JSONB DEFAULT '{}',
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_user_id ON orders(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_orders_status ON orders(status, created_at DESC);
CREATE INDEX idx_orders_stripe_payment_intent ON orders(stripe_payment_intent_id);

-- Order items (snapshot harga saat order)
CREATE TABLE order_items (
  id          BIGSERIAL PRIMARY KEY,
  order_id    BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id  BIGINT REFERENCES products(id) ON DELETE SET NULL,
  
  -- Snapshot (harga bisa berubah, tapi order history harus immutable)
  product_name    TEXT NOT NULL,
  product_sku     TEXT NOT NULL,
  unit_price      INTEGER NOT NULL,   -- harga saat order
  quantity        INTEGER NOT NULL,
  total_price     INTEGER NOT NULL,   -- unit_price * quantity
  
  -- Optional: variant snapshot
  variant_data    JSONB DEFAULT '{}'
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id) WHERE product_id IS NOT NULL;
```

---

## 3. INDEXING DEEP DIVE

```sql
-- B-tree Index (default) — untuk equality & range queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_posts_published_at ON posts(published_at DESC) WHERE status = 'published';
-- ↑ Partial index: hanya index rows yang memenuhi WHERE condition

-- Composite Index — urutan kolom SANGAT penting!
-- Rule: kolom dengan equality filter DULU, kemudian range/sort
CREATE INDEX idx_posts_author_status_date ON posts(author_id, status, created_at DESC);
-- Query yang benefit: WHERE author_id = 1 AND status = 'published' ORDER BY created_at DESC
-- Query yang TIDAK benefit: WHERE status = 'published' (tidak mulai dari author_id)

-- Covering Index — include semua kolom yang di-SELECT (hindari heap fetch)
CREATE INDEX idx_posts_listing ON posts(status, published_at DESC)
  INCLUDE (id, title, slug, excerpt, author_id);
-- Query: SELECT id, title, slug, excerpt, author_id FROM posts WHERE status = 'published' ORDER BY published_at DESC
-- ← bisa satisfied entirely dari index, tanpa heap lookup!

-- GIN Index — untuk JSONB, arrays, full-text search
CREATE INDEX idx_products_metadata ON products USING GIN(metadata);
-- Query: WHERE metadata @> '{"color": "red"}'

CREATE INDEX idx_posts_tags ON posts USING GIN(tags); -- jika tags adalah TEXT[]
-- Query: WHERE 'javascript' = ANY(tags)

-- Expression Index
CREATE INDEX idx_users_lower_email ON users(lower(email)); -- case-insensitive lookup
-- Query: WHERE lower(email) = lower('User@Example.com')

-- BRIN Index — untuk time-series data yang ter-insert secara sequential
CREATE INDEX idx_events_created_at ON events USING BRIN(created_at);
-- SANGAT compact, baik untuk large tables dengan natural ordering

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC; -- index dengan scan = 0 kemungkinan tidak berguna

-- Explain query plan
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM posts WHERE status = 'published' ORDER BY published_at DESC LIMIT 20;
-- Cari: "Index Scan" atau "Bitmap Index Scan" (GOOD) vs "Seq Scan" (BAD untuk large tables)
```

---

## 4. ADVANCED POSTGRESQL QUERIES

### Window Functions
```sql
-- ROW_NUMBER: ranking dalam partisi
SELECT 
  id, title, category_id,
  ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY view_count DESC) AS rank_in_category
FROM posts WHERE status = 'published';

-- LAG/LEAD: compare dengan row sebelum/sesudah
SELECT 
  date,
  revenue,
  LAG(revenue) OVER (ORDER BY date) AS prev_revenue,
  revenue - LAG(revenue) OVER (ORDER BY date) AS revenue_delta,
  ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY date)) / LAG(revenue) OVER (ORDER BY date), 2) AS pct_change
FROM daily_revenue
ORDER BY date;

-- PERCENTILE_CONT: untuk P50, P95, P99
SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_time_ms) AS p50,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95,
  PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms) AS p99
FROM api_logs WHERE created_at > now() - interval '1 hour';

-- Running totals & cumulative
SELECT 
  date,
  daily_signups,
  SUM(daily_signups) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_signups
FROM user_signups;
```

### CTEs (Common Table Expressions)
```sql
-- Recursive CTE untuk hierarchical data (menu, categories, org chart)
WITH RECURSIVE category_tree AS (
  -- Base case: root categories (no parent)
  SELECT id, name, parent_id, 0 AS depth, name::TEXT AS path
  FROM categories WHERE parent_id IS NULL
  
  UNION ALL
  
  -- Recursive case: child categories
  SELECT c.id, c.name, c.parent_id, ct.depth + 1, ct.path || ' > ' || c.name
  FROM categories c
  INNER JOIN category_tree ct ON c.parent_id = ct.id
  WHERE ct.depth < 10 -- prevent infinite recursion
)
SELECT * FROM category_tree ORDER BY path;

-- CTE untuk complex calculations
WITH 
monthly_revenue AS (
  SELECT 
    date_trunc('month', paid_at) AS month,
    SUM(total_amount) AS revenue
  FROM orders WHERE status = 'completed'
  GROUP BY 1
),
revenue_with_growth AS (
  SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue
  FROM monthly_revenue
)
SELECT 
  month,
  revenue,
  ROUND(100.0 * (revenue - prev_month_revenue) / prev_month_revenue, 2) AS mom_growth_pct
FROM revenue_with_growth ORDER BY month DESC;
```

### Full-Text Search
```sql
-- Setup
ALTER TABLE posts ADD COLUMN search_vector TSVECTOR;
UPDATE posts SET search_vector = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(content,''));
CREATE INDEX idx_posts_fts ON posts USING GIN(search_vector);

-- Search query dengan ranking
SELECT 
  id, title, slug,
  ts_rank(search_vector, query) AS rank,
  ts_headline('english', content, query, 'MaxWords=50, MinWords=25') AS excerpt
FROM posts, to_tsquery('english', 'web & performance | optimization') query
WHERE search_vector @@ query
  AND status = 'published'
ORDER BY rank DESC
LIMIT 20;

-- Auto-update search vector via trigger
CREATE FUNCTION update_search_vector() RETURNS trigger AS $$
BEGIN
  NEW.search_vector := to_tsvector('english', 
    coalesce(NEW.title, '') || ' ' || 
    coalesce(NEW.excerpt, '') || ' ' || 
    coalesce(NEW.content, '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER posts_search_vector_update
  BEFORE INSERT OR UPDATE OF title, excerpt, content ON posts
  FOR EACH ROW EXECUTE FUNCTION update_search_vector();
```

---

## 5. TRANSACTIONS & CONCURRENCY

```typescript
// Prisma transaction
const result = await db.$transaction(async (tx) => {
  // Semua operasi dalam satu transaction
  const order = await tx.order.create({ data: orderData });
  
  // Update stock — harus atomic!
  const product = await tx.product.update({
    where: { id: productId },
    data: { stockQuantity: { decrement: quantity } },
  });
  
  // Check stock tidak negatif
  if (product.stockQuantity < 0) {
    throw new Error('Insufficient stock'); // auto-rollback!
  }
  
  return order;
});

// Drizzle transaction
const result = await db.transaction(async (tx) => {
  const [order] = await tx.insert(orders).values(orderData).returning();
  await tx.update(products)
    .set({ stockQuantity: sql`${products.stockQuantity} - ${quantity}` })
    .where(and(eq(products.id, productId), gte(products.stockQuantity, quantity)));
  return order;
});

// Optimistic locking (prevent lost update)
-- Di schema: version column
ALTER TABLE products ADD COLUMN version INTEGER NOT NULL DEFAULT 0;

-- Di query: check version
UPDATE products 
SET stock_quantity = stock_quantity - 5, version = version + 1
WHERE id = 1 AND version = 3 -- hanya update jika version masih sama
RETURNING id;
-- Jika 0 rows updated → version conflict → retry!
```

---

## 6. REDIS DATA STRUCTURES UNTUK WEB

```typescript
import Redis from 'ioredis';
const redis = new Redis(process.env.REDIS_URL!);

// ── STRING ──
await redis.set('user:123:name', 'Alice', 'EX', 3600); // dengan TTL
await redis.get('user:123:name');
await redis.incr('page_view_counter'); // atomic increment

// ── HASH (object-like) ──
await redis.hset('user:123', { name: 'Alice', email: 'alice@example.com', plan: 'pro' });
await redis.hget('user:123', 'plan');
await redis.hgetall('user:123'); // semua fields
await redis.hincrby('user:123', 'api_calls', 1);

// ── SET (unique unordered) ──
await redis.sadd('active_users', 'user:123', 'user:456');
await redis.sismember('active_users', 'user:123'); // check membership: O(1)
await redis.scard('active_users'); // count members
await redis.smembers('active_users'); // get all

// ── SORTED SET (ranking, leaderboard) ──
await redis.zadd('leaderboard', 1500, 'user:123'); // score, member
await redis.zadd('leaderboard', 2000, 'user:456');
await redis.zrange('leaderboard', 0, 9, 'REV', 'WITHSCORES'); // top 10 descending
await redis.zrank('leaderboard', 'user:123'); // position (0-indexed)
await redis.zincrby('leaderboard', 100, 'user:123'); // add score

// ── LIST (queue, recent items) ──
await redis.lpush('job_queue', JSON.stringify(job)); // push ke depan
await redis.rpop('job_queue'); // pop dari belakang (FIFO queue)
await redis.lrange('recent_views:user:123', 0, 9); // last 10 viewed

// ── RATE LIMITING dengan Sorted Set (Sliding Window) ──
async function checkRateLimit(key: string, limit: number, windowMs: number): Promise<boolean> {
  const now = Date.now();
  const windowStart = now - windowMs;
  
  const pipeline = redis.pipeline();
  pipeline.zremrangebyscore(key, '-inf', windowStart); // remove old entries
  pipeline.zadd(key, now, `${now}-${Math.random()}`); // add current request
  pipeline.zcard(key); // count in window
  pipeline.expire(key, Math.ceil(windowMs / 1000)); // cleanup TTL
  
  const results = await pipeline.exec();
  const count = results![2][1] as number;
  
  return count <= limit; // true = allowed
}

// ── PUB/SUB ──
// Publisher:
await redis.publish('notifications:user:123', JSON.stringify({ type: 'message', data: { text: 'Hello!' } }));

// Subscriber (separate connection!):
const subscriber = redis.duplicate();
await subscriber.subscribe('notifications:user:123');
subscriber.on('message', (channel, message) => {
  const event = JSON.parse(message);
  // handle event
});

// ── DISTRIBUTED LOCK (Redlock) ──
import Redlock from 'redlock';
const redlock = new Redlock([redis], { retryCount: 3, retryDelay: 200 });

async function processWithLock(resourceId: string) {
  const lock = await redlock.acquire([`lock:${resourceId}`], 5000); // 5s TTL
  try {
    // Critical section — hanya 1 instance bisa masuk
    await processExpensiveOperation(resourceId);
  } finally {
    await lock.release();
  }
}
```

---

## 7. DATABASE MIGRATION BEST PRACTICES

```typescript
// Drizzle ORM migrations
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit';
export default defineConfig({
  schema: './src/lib/db/schema.ts',
  out: './drizzle/migrations',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
  strict: true,
});

// Generate migration setelah schema change:
npx drizzle-kit generate

// Apply migration:
npx drizzle-kit migrate

// Prisma migrations
npx prisma migrate dev --name add_stripe_customer_id
npx prisma migrate deploy  // production
```

```sql
-- Zero-downtime migration: Expand-Contract Pattern
-- Contoh: rename column email → email_address

-- STEP 1: EXPAND — tambah column baru
ALTER TABLE users ADD COLUMN email_address TEXT;

-- STEP 2: BACKFILL — isi data (bisa sambil traffic jalan)
UPDATE users SET email_address = email WHERE email_address IS NULL;

-- STEP 3: CONSTRAINT — set NOT NULL setelah backfill complete
ALTER TABLE users ALTER COLUMN email_address SET NOT NULL;

-- STEP 4: CODE SWITCH — deploy aplikasi baru yang baca dari email_address

-- STEP 5: CONTRACT — hapus column lama (deployment berikutnya)
ALTER TABLE users DROP COLUMN email;

-- ❌ JANGAN lakukan ini langsung:
-- ALTER TABLE users RENAME COLUMN email TO email_address;
-- ← App lama crash karena query ke kolom 'email' yang sudah tidak ada!
```

---

## 8. DATABASE BACKUP & MONITORING

```bash
# pg_dump untuk backup logical
pg_dump -Fc -Z 9 -d $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).dump

# Restore
pg_restore -d $TARGET_DATABASE_URL backup.dump

# Script backup otomatis ke S3:
#!/bin/bash
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).dump"
pg_dump -Fc -Z 9 -d "$DATABASE_URL" > "/tmp/$BACKUP_FILE"
aws s3 cp "/tmp/$BACKUP_FILE" "s3://$S3_BUCKET/db-backups/$BACKUP_FILE"
rm "/tmp/$BACKUP_FILE"
echo "Backup complete: $BACKUP_FILE"

# Monitoring slow queries
-- Enable di postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all

-- Query slow queries
SELECT 
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2) AS avg_ms,
  calls,
  round((total_exec_time / calls)::numeric, 2) AS per_call_ms,
  left(query, 100) AS query_snippet
FROM pg_stat_statements
WHERE calls > 100
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Table bloat monitoring
SELECT schemaname, tablename, 
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size
FROM pg_tables WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index usage stats
SELECT indexrelname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
-- Indexes dengan idx_scan = 0 = tidak pernah dipakai → kandidat untuk di-drop
```

---

*Bxploit Database Mastery — Data layer yang kuat = app yang kuat. Gas pol. 🗄️🔥*
